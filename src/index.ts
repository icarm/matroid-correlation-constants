import { Hono } from 'hono'
import {
  acknowledgePage,
  activityPage,
  apiDocsPage,
  commentaryHistoryPage,
  landingPage,
  matroidDetailPage,
  matroidsPage,
  notFoundPage,
  profilePage,
  resultPage,
  type FormState,
} from './pages'
import {
  type AppEnv,
  generateApiToken,
  loadCurrentUser,
  loadUserFromToken,
  startOAuth,
  handleCallback,
  logout,
  updateSessionUser,
} from './auth'
import {
  allMatroids,
  COMMENT_MAX,
  commentaryHistory,
  currentRecords,
  listTokens,
  loadMatroid,
  postCommentary,
  recentActivity,
  recordMatroid,
  userMatroids,
  type RecordStatus,
} from './store'
import {
  MAX_DATA_TEXT_BYTES,
  PROVENANCE_MAX,
  REPRESENTATION_TYPES,
  verify,
  type VerifyResult,
} from './verify'
import {
  checkSubmissionRateLimit,
  SUBMISSION_RATE_LIMIT,
  SUBMISSION_RATE_PERIOD_SEC,
} from './rateLimit'

const rateLimitMessage = `submission rate limit exceeded: ${SUBMISSION_RATE_LIMIT} per ${SUBMISSION_RATE_PERIOD_SEC} seconds`

const app = new Hono<AppEnv>()

// Resolve the current user (session cookie, else API bearer token) for every
// request. Both lookups short-circuit cheaply when their credential is absent.
app.use('*', async (c, next) => {
  const user = (await loadCurrentUser(c)) ?? (await loadUserFromToken(c))
  c.set('user', user)
  await next()
})

app.get('/', async (c) =>
  c.html(
    landingPage(c.get('user'), await currentRecords(c.env), c.req.query('expired') === '1'),
  ),
)

app.get('/auth/:provider', startOAuth)
app.get('/auth/:provider/callback', handleCallback)
app.post('/auth/logout', logout)

app.get('/api', (c) => c.html(apiDocsPage(c.get('user'))))

// A JSON attachment response with a strong ETag over the exact body, so
// clients can revalidate cheaply. no-cache = clients may store but must
// revalidate every time; paired with the ETag, a fresh request returns 304
// (no body) when nothing changed — the body only changes when a record does.
async function jsonDownload(req: Request, payload: string, filename: string): Promise<Response> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(payload))
  const etag =
    '"' +
    [...new Uint8Array(digest)]
      .slice(0, 16)
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('') +
    '"'
  const headers = {
    'content-type': 'application/json; charset=UTF-8',
    'content-disposition': `attachment; filename="${filename}"`,
    'cache-control': 'no-cache',
    etag,
  }
  if (req.headers.get('if-none-match') === etag) return new Response(null, { status: 304, headers })
  return new Response(payload, { status: 200, headers })
}

// Every record matroid (current and superseded) as one JSON download.
app.get('/database.json', async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.max_pairs, m.max_counts, m.representation_type, m.representation,
            m.field, m.bases, m.provenance, m.created_at,
            u.display_name AS submitter,
            (m.id = (SELECT MAX(id) FROM matroids WHERE n = m.n)) AS is_current
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       ORDER BY m.n, m.id`,
  ).all<{
    id: number
    n: number
    rank: number
    num_bases: number
    alpha_num: number
    alpha_den: number
    alpha_value: number
    max_pairs: string
    max_counts: string | null
    representation_type: string
    representation: string
    field: string | null
    bases: string | null
    provenance: string | null
    created_at: string
    submitter: string | null
    is_current: number
  }>()
  const parse = (s: string | null): unknown => {
    if (s === null) return null
    try {
      return JSON.parse(s)
    } catch {
      return null
    }
  }
  const matroids = results.map((r) => ({
    id: r.id,
    n: r.n,
    rank: r.rank,
    num_bases: r.num_bases,
    alpha: { numerator: r.alpha_num, denominator: r.alpha_den, value: r.alpha_value },
    max_pairs: parse(r.max_pairs),
    max_counts: parse(r.max_counts),
    representation_type: r.representation_type,
    representation: parse(r.representation),
    field: r.field,
    bases: parse(r.bases),
    provenance: r.provenance,
    submitter: r.submitter,
    created_at: r.created_at,
    current: !!r.is_current,
  }))
  const payload = JSON.stringify({ count: matroids.length, matroids }, null, 2)
  return jsonDownload(c.req.raw, payload, 'matroid-correlation-records.json')
})

app.get('/acknowledge', (c) => c.html(acknowledgePage(c.get('user'))))

app.get('/matroids', async (c) =>
  c.html(
    matroidsPage(
      await allMatroids(c.env),
      {
        sort: c.req.query('sort'),
        dir: c.req.query('dir'),
        current: c.req.query('current'),
        n: c.req.query('n'),
      },
      c.get('user'),
    ),
  ),
)

app.get('/matroid/:id', async (c) => {
  const id = Number(c.req.param('id'))
  if (!Number.isInteger(id)) return c.html(notFoundPage(c.get('user')), 404)
  const loaded = await loadMatroid(c.env, id)
  if (!loaded) return c.html(notFoundPage(c.get('user')), 404)
  return c.html(
    matroidDetailPage(loaded.matroid, loaded.comment, c.get('user'), c.req.query('new') === '1'),
  )
})

app.post('/matroid/:id/commentary', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github', 302)
  const id = Number(c.req.param('id'))
  if (!Number.isInteger(id)) return c.html(notFoundPage(user), 404)
  const exists = await c.env.DB.prepare('SELECT id FROM matroids WHERE id = ?').bind(id).first()
  if (!exists) return c.html(notFoundPage(user), 404)
  const form = await c.req.parseBody()
  // An explicit empty string is a deliberate "clear"; a missing field is a
  // malformed request and must not clear anything.
  if (typeof form.content !== 'string') {
    return c.text('missing or invalid form field: content', 400)
  }
  const content = form.content.slice(0, COMMENT_MAX)
  await postCommentary(c.env, id, user.id, content)
  return c.redirect(`/matroid/${id}`, 302)
})

app.get('/matroid/:id/commentary-history', async (c) => {
  const id = Number(c.req.param('id'))
  if (!Number.isInteger(id)) return c.html(notFoundPage(c.get('user')), 404)
  const loaded = await loadMatroid(c.env, id)
  if (!loaded) return c.html(notFoundPage(c.get('user')), 404)
  return c.html(
    commentaryHistoryPage(loaded.matroid, await commentaryHistory(c.env, id), c.get('user')),
  )
})

app.get('/recent', async (c) => {
  const p = Math.max(0, Math.floor(Number(c.req.query('p')) || 0))
  const { items, page, hasOlder } = await recentActivity(c.env, p)
  return c.html(activityPage(items, page, hasOlder, c.get('user')))
})

app.get('/profile', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github?return_to=/profile', 302)
  const [tokens, matroids] = await Promise.all([
    listTokens(c.env, user.id),
    userMatroids(c.env, user.id),
  ])
  return c.html(profilePage(user, tokens, null, matroids))
})

app.post('/profile/tokens', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github', 302)
  const form = await c.req.parseBody()
  const name = String(form.name ?? '').trim().slice(0, 100) || null
  const newToken = await generateApiToken(c.env, user.id, name)
  const [tokens, matroids] = await Promise.all([
    listTokens(c.env, user.id),
    userMatroids(c.env, user.id),
  ])
  return c.html(profilePage(user, tokens, newToken, matroids))
})

app.post('/profile/tokens/:id/revoke', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github', 302)
  const id = Number(c.req.param('id'))
  if (Number.isInteger(id)) {
    await c.env.DB.prepare(
      'UPDATE api_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ? AND revoked_at IS NULL',
    )
      .bind(id, user.id)
      .run()
  }
  return c.redirect('/profile', 302)
})

app.post('/profile/name', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github', 302)
  const form = await c.req.parseBody()
  const name = String(form.name ?? '').trim().slice(0, 100)
  if (name) {
    await c.env.DB.prepare('UPDATE users SET display_name = ? WHERE id = ?').bind(name, user.id).run()
    await updateSessionUser(c, { display_name: name })
  }
  return c.redirect('/profile', 302)
})

function verifyFromText(
  nText: string,
  typeText: string,
  fieldText: string,
  dataText: string,
): VerifyResult {
  if (dataText.length > MAX_DATA_TEXT_BYTES) {
    return { ok: false, error: 'submission too large' }
  }
  const nTrimmed = nText.trim()
  if (!/^\d+$/.test(nTrimmed)) {
    return { ok: false, error: 'n must be a positive integer' }
  }
  let data: unknown
  try {
    data = JSON.parse(dataText)
  } catch (e) {
    return { ok: false, error: `the data box must contain valid JSON (${(e as Error).message})` }
  }
  return verify(Number(nTrimmed), typeText.trim(), fieldText, data)
}

// A stray GET (old bookmark, stale OAuth return) lands home rather than 404.
app.get('/verify', (c) => c.redirect('/', 302))

// Verdict + form state stashed between the POST and the redirected GET.
// The bases list and normalized representation are dropped from the stored
// result (the page never shows them; the form echo comes from the raw text
// in `form`).
interface ResultFlash {
  result: VerifyResult
  record?: RecordStatus
  form: FormState
}

const RESULT_FLASH_TTL_SEC = 10 * 60

/** Trim the heavyweight fields before flashing a result to KV. */
function slimResult(result: VerifyResult): VerifyResult {
  if (!result.ok) return result
  return { ...result, representation: '', basesJson: null }
}

// Post/Redirect/Get: a record-setting submission redirects to its new matroid
// page; anything else stores a short-lived flash and redirects to /result/:key,
// so reloading the result never re-submits the form.
app.post('/verify', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github?return_to=/', 302)
  const rate = await checkSubmissionRateLimit(c.env, user.id)
  if (!rate.allowed) {
    c.header('Retry-After', String(rate.retryAfter))
    return c.html(
      resultPage(
        user,
        { ok: false, error: `${rateLimitMessage}; retry in about ${rate.retryAfter} seconds` },
        undefined,
        {},
      ),
      429,
    )
  }
  const body = await c.req.parseBody()
  const nText = typeof body.n === 'string' ? body.n : ''
  const typeText = typeof body.type === 'string' ? body.type : ''
  const fieldText = typeof body.field === 'string' ? body.field : ''
  const dataText = typeof body.data === 'string' ? body.data : ''
  const provenance =
    typeof body.provenance === 'string' ? body.provenance.trim().slice(0, PROVENANCE_MAX) : ''
  const result = verifyFromText(nText, typeText, fieldText, dataText)
  let record: RecordStatus | undefined
  if (result.ok) {
    record = await recordMatroid(c.env, result, provenance || null, user.id)
    if (record.recorded) return c.redirect(`/matroid/${record.matroidId}?new=1`, 303)
  }
  const flash: ResultFlash = {
    result: slimResult(result),
    record,
    form: {
      nValue: nText,
      typeValue: typeText,
      fieldValue: fieldText,
      dataValue: dataText,
      provenanceValue: provenance,
    },
  }
  const key = crypto.randomUUID()
  await c.env.SESSIONS.put(`result:${key}`, JSON.stringify(flash), {
    expirationTtl: RESULT_FLASH_TTL_SEC,
  })
  return c.redirect(`/result/${key}`, 303)
})

app.get('/result/:key', async (c) => {
  const key = c.req.param('key')
  if (!/^[0-9a-f-]{36}$/.test(key)) return c.html(notFoundPage(c.get('user')), 404)
  const flash = (await c.env.SESSIONS.get(`result:${key}`, 'json')) as ResultFlash | null
  if (!flash) return c.redirect('/?expired=1', 302)
  return c.html(resultPage(c.get('user'), flash.result, flash.record, flash.form))
})

app.post('/api/verify', async (c) => {
  const user = c.get('user')
  if (!user) return c.json({ ok: false, error: 'authentication required' }, 401)
  const rate = await checkSubmissionRateLimit(c.env, user.id)
  if (!rate.allowed) {
    c.header('Retry-After', String(rate.retryAfter))
    return c.json(
      {
        ok: false,
        error: `${rateLimitMessage}; retry in about ${rate.retryAfter} seconds`,
        rateLimit: {
          limit: SUBMISSION_RATE_LIMIT,
          period: SUBMISSION_RATE_PERIOD_SEC,
          retryAfter: rate.retryAfter,
        },
      },
      429,
    )
  }
  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ ok: false, error: 'request body must be JSON' }, 400)
  }
  const { n, type, field, data, provenance } = (body ?? {}) as {
    n?: unknown
    type?: unknown
    field?: unknown
    data?: unknown
    provenance?: unknown
  }
  if (typeof n !== 'number' || typeof type !== 'string' || data === undefined) {
    return c.json(
      {
        ok: false,
        error: `expected {"n": <integer>, "type": <one of ${REPRESENTATION_TYPES.join('|')}>, "data": [...], "field"?: "Q"|"<prime>", "provenance"?: <string>}`,
      },
      400,
    )
  }
  const fieldText = typeof field === 'number' ? String(field) : typeof field === 'string' ? field : ''
  const provenanceText =
    typeof provenance === 'string' ? provenance.trim().slice(0, PROVENANCE_MAX) : ''
  const result = verify(n, type, fieldText, data)
  if (!result.ok) return c.json(result, 400)
  const record = await recordMatroid(c.env, result, provenanceText || null, user.id)
  // Echoing the (possibly large) bases and description back is redundant for
  // API users.
  const { basesJson: _bases, representation: _rep, ...rest } = result
  return c.json({ ...rest, record })
})

app.notFound((c) => c.html(notFoundPage(c.get('user')), 404))

export default app
