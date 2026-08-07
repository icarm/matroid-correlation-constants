import { Hono } from 'hono'
import {
  acknowledgePage,
  activityPage,
  familyProposeResultPage,
  landingPage,
  type FamilyFormState,
  matroidDetailPage,
  matroidsPage,
  notFoundPage,
  profilePage,
  resultPage,
  type FormState,
} from './pages'
import {
  type AppEnv,
  loadCurrentUser,
  startOAuth,
  handleCallback,
  logout,
  updateSessionUser,
} from './auth'
import {
  allMatroids,
  recordPoints,
  loadMatroid,
  recentActivity,
  recordMatroid,
  userMatroids,
  type RecordStatus,
  type SubmissionMeta,
} from './store'
import {
  MAX_DATA_TEXT_BYTES,
  PROVENANCE_MAX,
  verify,
  type VerifyResult,
} from './verify'
import {
  checkSubmissionRateLimit,
  SUBMISSION_RATE_LIMIT,
  SUBMISSION_RATE_PERIOD_SEC,
} from './rateLimit'
import { mathematicsPage } from './mathematics'
import { familiesPage, familyPage } from './families'
import {
  acceptedFamilies,
  familyBySlug,
  isAdmin,
  parseFamilyProposal,
  pendingFamilies,
  reviewFamily,
  submitFamily,
} from './familyStore'

const rateLimitMessage = `submission rate limit exceeded: ${SUBMISSION_RATE_LIMIT} per ${SUBMISSION_RATE_PERIOD_SEC} seconds`

const app = new Hono<AppEnv>()

// Resolve the current user (session cookie) for every request; the lookup
// short-circuits cheaply when the cookie is absent.
app.use('*', async (c, next) => {
  c.set('user', await loadCurrentUser(c))
  await next()
})

app.get('/', async (c) => {
  const [records, families] = await Promise.all([recordPoints(c.env), acceptedFamilies(c.env)])
  return c.html(landingPage(c.get('user'), records, families, c.req.query('expired') === '1'))
})

app.get('/auth/:provider', startOAuth)
app.get('/auth/:provider/callback', handleCallback)
app.post('/auth/logout', logout)

app.get('/mathematics', (c) => c.html(mathematicsPage(c.get('user'))))

app.get('/families', async (c) => {
  const user = c.get('user')
  const [families, admin] = await Promise.all([
    acceptedFamilies(c.env),
    isAdmin(c.env, user?.id ?? null),
  ])
  const pending = admin ? await pendingFamilies(c.env) : []
  return c.html(familiesPage(families, pending, user))
})

app.get('/family/:slug', async (c) => {
  const user = c.get('user')
  const family = await familyBySlug(c.env, c.req.param('slug'))
  if (!family) return c.html(notFoundPage(user), 404)
  const admin = await isAdmin(c.env, user?.id ?? null)
  // Accepted families are public; a pending or rejected proposal exists
  // only for its submitter and the admins.
  if (family.status !== 'accepted' && !admin && family.submitterUserId !== (user?.id ?? -1)) {
    return c.html(notFoundPage(user), 404)
  }
  return c.html(familyPage(family, user, admin))
})

// The field whitelist doubles as the form echo: whatever the user typed
// comes back verbatim on a validation error.
const FAMILY_FORM_FIELDS = [
  'name',
  'short',
  'claim',
  'parameter',
  'formula_tex',
  'size_rank_tex',
  'supremum',
  'supremum_kind',
  'summary',
  'construction',
  'curve_explanation',
  'proof_status',
  'proof_url',
  'series',
  'contributors',
  'discovery_date',
  'ai_used',
  'ai_model',
  'ai_role',
  'ai_chat_url',
] as const

app.post('/families/propose', async (c) => {
  const user = c.get('user')
  if (!user) {
    return c.redirect('/auth/github?return_to=' + encodeURIComponent('/#submit-family'), 302)
  }
  const rate = await checkSubmissionRateLimit(c.env, user.id)
  if (!rate.allowed) {
    c.header('Retry-After', String(rate.retryAfter))
    return c.html(
      familyProposeResultPage(
        user,
        `${rateLimitMessage}; retry in about ${rate.retryAfter} seconds`,
        {},
      ),
      429,
    )
  }
  const body = await c.req.parseBody()
  const form: FamilyFormState = {}
  for (const key of FAMILY_FORM_FIELDS) {
    const v = body[key]
    if (typeof v === 'string') form[key] = v
  }
  const proposal = parseFamilyProposal(form)
  if ('error' in proposal) return c.html(familyProposeResultPage(user, proposal.error, form), 400)
  const { slug } = await submitFamily(c.env, proposal, user.id)
  // The proposal's own page: pending, visible to the submitter and admins.
  return c.redirect(`/family/${slug}`, 303)
})

app.post('/family/:slug/review', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github', 302)
  if (!(await isAdmin(c.env, user.id))) return c.text('reviewing proposals requires an admin', 403)
  const family = await familyBySlug(c.env, c.req.param('slug'))
  if (!family) return c.html(notFoundPage(user), 404)
  const body = await c.req.parseBody()
  const action = body.action === 'accept' ? 'accept' : body.action === 'reject' ? 'reject' : null
  if (action === null) return c.text('action must be accept or reject', 400)
  const note =
    typeof body.note === 'string' && body.note.trim() !== ''
      ? body.note.trim().slice(0, 2000)
      : null
  await reviewFamily(c.env, family.id, action, user.id, note)
  return c.redirect(`/family/${family.slug}`, 303)
})

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
            m.field, m.cert_field, m.cert_matrix, m.bases, m.provenance, m.created_at,
            m.name, m.discoverers, m.discovery_date, m.ai_used, m.ai_model,
            m.ai_role, m.ai_chat_url, m.citation, m.verifier_version,
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
    cert_field: string | null
    cert_matrix: string | null
    bases: string | null
    provenance: string | null
    created_at: string
    name: string | null
    discoverers: string | null
    discovery_date: string | null
    ai_used: number | null
    ai_model: string | null
    ai_role: string | null
    ai_chat_url: string | null
    citation: string | null
    verifier_version: string | null
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
    name: r.name,
    n: r.n,
    rank: r.rank,
    num_bases: r.num_bases,
    alpha: { numerator: r.alpha_num, denominator: r.alpha_den, value: r.alpha_value },
    max_pairs: parse(r.max_pairs),
    max_counts: parse(r.max_counts),
    representation_type: r.representation_type,
    representation: parse(r.representation),
    field: r.field,
    cert_field: r.cert_field,
    cert_matrix: parse(r.cert_matrix),
    bases: parse(r.bases),
    discovery: {
      date: r.discovery_date,
      discoverers: r.discoverers,
      ai_used: r.ai_used === null ? null : !!r.ai_used,
      ai_model: r.ai_model,
      ai_role: r.ai_role,
      ai_chat_url: r.ai_chat_url,
    },
    citation: r.citation,
    provenance: r.provenance,
    verifier_version: r.verifier_version,
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
  const matroid = await loadMatroid(c.env, id)
  if (!matroid) return c.html(notFoundPage(c.get('user')), 404)
  return c.html(matroidDetailPage(matroid, c.get('user'), c.req.query('new') === '1'))
})

app.get('/recent', async (c) => {
  const p = Math.max(0, Math.floor(Number(c.req.query('p')) || 0))
  const { items, page, hasOlder } = await recentActivity(c.env, p)
  return c.html(activityPage(items, page, hasOlder, c.get('user')))
})

app.get('/profile', async (c) => {
  const user = c.get('user')
  if (!user) return c.redirect('/auth/github?return_to=/profile', 302)
  return c.html(profilePage(user, await userMatroids(c.env, user.id)))
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

// Discovery dates are YYYY-MM or YYYY-MM-DD, as in the draft site's schema
// (discovery is distinct from the submission timestamp GitHub-style metadata
// records automatically).
const DISCOVERY_DATE_RE = /^\d{4}-(0[1-9]|1[0-2])(-(0[1-9]|[12]\d|3[01]))?$/

/** Validate and trim the structured discovery metadata. All fields are
 * optional, but what is supplied must be coherent: a real date shape, an
 * http(s) chat link, and a model + role whenever AI use is declared. */
function parseMeta(raw: {
  name?: unknown
  discoverers?: unknown
  discoveryDate?: unknown
  aiUsed?: unknown
  aiModel?: unknown
  aiRole?: unknown
  aiChatUrl?: unknown
  citation?: unknown
  provenance?: unknown
}): SubmissionMeta | { error: string } {
  const text = (v: unknown, max: number): string | null =>
    typeof v === 'string' && v.trim() !== '' ? v.trim().slice(0, max) : null
  const meta: SubmissionMeta = {
    name: text(raw.name, 200),
    discoverers: text(raw.discoverers, 500),
    discoveryDate: text(raw.discoveryDate, 10),
    aiUsed:
      typeof raw.aiUsed === 'boolean'
        ? raw.aiUsed
        : raw.aiUsed === 'yes'
          ? true
          : raw.aiUsed === 'no'
            ? false
            : null,
    aiModel: text(raw.aiModel, 200),
    aiRole: text(raw.aiRole, 1000),
    aiChatUrl: text(raw.aiChatUrl, 500),
    citation: text(raw.citation, 500),
    provenance: text(raw.provenance, PROVENANCE_MAX),
  }
  if (meta.discoveryDate !== null && !DISCOVERY_DATE_RE.test(meta.discoveryDate)) {
    return { error: 'discovery date must be YYYY-MM or YYYY-MM-DD' }
  }
  if (meta.aiChatUrl !== null && !/^https?:\/\//.test(meta.aiChatUrl)) {
    return { error: 'the AI chat link must be an http(s) URL' }
  }
  if (meta.aiUsed === true && (meta.aiModel === null || meta.aiRole === null)) {
    return {
      error: 'when AI use is declared, the model/version and a brief role description are required',
    }
  }
  return meta
}

/** Parse an optional claimed α: an exact nonnegative fraction as "a/b", an
 * integer, or {"numerator", "denominator"}. Decimals are refused — the whole
 * point of the claim is exactness. Returns null when absent. */
function parseClaimedAlpha(
  raw: unknown,
): { num: bigint; den: bigint } | null | { error: string } {
  if (raw === undefined || raw === null || raw === '') return null
  let text: string
  if (typeof raw === 'string') text = raw.trim()
  else if (typeof raw === 'number' && Number.isSafeInteger(raw) && raw >= 0) text = String(raw)
  else if (typeof raw === 'object') {
    const o = raw as { numerator?: unknown; denominator?: unknown }
    if (
      typeof o.numerator === 'number' &&
      Number.isSafeInteger(o.numerator) &&
      typeof o.denominator === 'number' &&
      Number.isSafeInteger(o.denominator)
    ) {
      text = `${o.numerator}/${o.denominator}`
    } else {
      return { error: 'claimed α must be "a/b", an integer, or {"numerator": a, "denominator": b}' }
    }
  } else {
    return { error: 'claimed α must be "a/b", an integer, or {"numerator": a, "denominator": b}' }
  }
  if (text === '') return null
  const m = /^(\d{1,15})(?:\s*\/\s*([1-9]\d{0,14}))?$/.exec(text)
  if (!m) {
    return {
      error: `could not parse the claimed α ${JSON.stringify(text)}: give an exact nonnegative fraction like "100/81" (decimals are not exact)`,
    }
  }
  return { num: BigInt(m[1]), den: m[2] ? BigInt(m[2]) : 1n }
}

/** Exact claim-versus-computed comparison; a mismatch is the tripwire for
 * "the data does not describe the matroid the submitter had in mind". */
function claimMismatch(
  claim: { num: bigint; den: bigint },
  result: { alphaNum: number; alphaDen: number; alphaValue: number },
): string | null {
  if (BigInt(result.alphaNum) * claim.den === claim.num * BigInt(result.alphaDen)) return null
  return (
    `the claimed α = ${claim.num}/${claim.den} does not match the verified α = ` +
    `${result.alphaNum}/${result.alphaDen} ≈ ${result.alphaValue.toFixed(6)} — ` +
    'check that the data describes the intended matroid (nothing was recorded)'
  )
}

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
  const form: FormState = {
    nValue: nText,
    typeValue: typeText,
    fieldValue: fieldText,
    dataValue: dataText,
    nameValue: typeof body.name === 'string' ? body.name : '',
    discoverersValue: typeof body.discoverers === 'string' ? body.discoverers : '',
    discoveryDateValue: typeof body.discovery_date === 'string' ? body.discovery_date : '',
    aiUsedValue: typeof body.ai_used === 'string' ? body.ai_used : '',
    aiModelValue: typeof body.ai_model === 'string' ? body.ai_model : '',
    aiRoleValue: typeof body.ai_role === 'string' ? body.ai_role : '',
    aiChatUrlValue: typeof body.ai_chat_url === 'string' ? body.ai_chat_url : '',
    citationValue: typeof body.citation === 'string' ? body.citation : '',
    provenanceValue: typeof body.provenance === 'string' ? body.provenance : '',
    claimedAlphaValue: typeof body.claimed_alpha === 'string' ? body.claimed_alpha : '',
  }
  const meta = parseMeta({
    name: form.nameValue,
    discoverers: form.discoverersValue,
    discoveryDate: form.discoveryDateValue,
    aiUsed: form.aiUsedValue,
    aiModel: form.aiModelValue,
    aiRole: form.aiRoleValue,
    aiChatUrl: form.aiChatUrlValue,
    citation: form.citationValue,
    provenance: form.provenanceValue,
  })
  const claim = parseClaimedAlpha(form.claimedAlphaValue)
  let result: VerifyResult =
    'error' in meta
      ? { ok: false, error: meta.error }
      : claim !== null && 'error' in claim
        ? { ok: false, error: claim.error }
        : verifyFromText(nText, typeText, fieldText, dataText)
  if (result.ok && claim !== null && !('error' in claim)) {
    const mismatch = claimMismatch(claim, result)
    if (mismatch) result = { ok: false, error: mismatch }
  }
  let record: RecordStatus | undefined
  if (result.ok && !('error' in meta)) {
    record = await recordMatroid(c.env, result, meta, user.id)
    if (record.recorded) return c.redirect(`/matroid/${record.matroidId}?new=1`, 303)
  }
  const flash: ResultFlash = {
    result: slimResult(result),
    record,
    form,
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

app.notFound((c) => c.html(notFoundPage(c.get('user')), 404))

export default app
