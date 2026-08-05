// D1 persistence for record matroids. The matroids table is append-only:
// every record-setting matroid is kept, so the history of records for a
// ground-set size survives being beaten. Within one n records only ever
// strictly increase, so the row with the largest id is the current record.

import type { Bindings } from './auth'
import type { RecordPoint, TokenRow, UserMatroidRow } from './pages'
import type { VerifiedMatroid } from './verify'

export const COMMENT_MAX = 4000

// Canonical bases lists are stored only up to this size; the entry is always
// recomputable from its stored representation. (Keeps rows well under D1's
// per-value limits even for matrix submissions with tens of thousands of bases.)
const BASES_STORE_MAX = 200_000

export interface CommentView {
  id: number
  content: string
  created_at: string
  author: string | null
}

/** One matroid row as shown on its page. */
export interface MatroidView {
  id: number
  n: number
  rank: number
  num_bases: number
  alpha_num: number
  alpha_den: number
  alpha_value: number
  max_pairs: string // JSON list of [i, j]
  max_counts: string | null // JSON MaxCounts
  representation_type: string
  representation: string
  field: string | null
  bases: string | null
  provenance: string | null
  created_at: string
  submitter_name: string | null
  current_comment_id: number | null
  record_id: number // row id of the current record for this n
  record_alpha_num: number
  record_alpha_den: number
}

export async function loadMatroid(
  env: Bindings,
  id: number,
): Promise<{ matroid: MatroidView; comment: CommentView | null } | null> {
  const matroid = await env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.max_pairs, m.max_counts, m.representation_type, m.representation,
            m.field, m.bases, m.provenance, m.created_at, m.current_comment_id,
            u.display_name AS submitter_name,
            (SELECT id FROM matroids WHERE n = m.n ORDER BY id DESC LIMIT 1) AS record_id,
            (SELECT alpha_num FROM matroids WHERE n = m.n ORDER BY id DESC LIMIT 1) AS record_alpha_num,
            (SELECT alpha_den FROM matroids WHERE n = m.n ORDER BY id DESC LIMIT 1) AS record_alpha_den
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       WHERE m.id = ?`,
  )
    .bind(id)
    .first<MatroidView>()
  if (!matroid) return null
  let comment: CommentView | null = null
  if (matroid.current_comment_id != null) {
    comment = await env.DB.prepare(
      `SELECT cl.id, cl.content, cl.created_at, u.display_name AS author
         FROM commentary_log cl LEFT JOIN users u ON u.id = cl.user_id
         WHERE cl.id = ?`,
    )
      .bind(matroid.current_comment_id)
      .first<CommentView>()
  }
  return { matroid, comment }
}

// Record an edit to a matroid's commentary and point the matroid at it.
export async function postCommentary(
  env: Bindings,
  matroidId: number,
  userId: number,
  content: string,
): Promise<void> {
  const ins = await env.DB.prepare(
    'INSERT INTO commentary_log (matroid_id, user_id, content) VALUES (?, ?, ?)',
  )
    .bind(matroidId, userId, content)
    .run()
  await env.DB.prepare('UPDATE matroids SET current_comment_id = ? WHERE id = ?')
    .bind(ins.meta.last_row_id, matroidId)
    .run()
}

// Full edit history for a matroid, newest first.
export function commentaryHistory(env: Bindings, matroidId: number): Promise<CommentView[]> {
  return env.DB.prepare(
    `SELECT cl.id, cl.content, cl.created_at, u.display_name AS author
       FROM commentary_log cl LEFT JOIN users u ON u.id = cl.user_id
       WHERE cl.matroid_id = ? ORDER BY cl.id DESC`,
  )
    .bind(matroidId)
    .all<CommentView>()
    .then((r) => r.results)
}

// One row in the recent-activity feed: a record-setting matroid or a
// commentary edit. Both carry the entry's n and correlation constant.
export interface ActivityItem {
  kind: 'record' | 'commentary'
  ts: string
  matroid_id: number
  n: number
  alpha_num: number
  alpha_den: number
  user: string | null
  content: string | null
}

export const ACTIVITY_PAGE_SIZE = 30

// Recent activity, newest first, paginated. Merges record matroids and
// commentary edits in one timeline. `hasOlder` reports whether a further page
// exists (we fetch one extra row to find out).
export async function recentActivity(
  env: Bindings,
  page = 0,
): Promise<{ items: ActivityItem[]; page: number; hasOlder: boolean }> {
  const size = ACTIVITY_PAGE_SIZE
  const { results } = await env.DB.prepare(
    `SELECT kind, ts, matroid_id, n, alpha_num, alpha_den, user, content FROM (
         SELECT 'record' AS kind, m.created_at AS ts, m.id AS matroid_id,
                m.n, m.alpha_num, m.alpha_den, u.display_name AS user, NULL AS content
           FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
         UNION ALL
         SELECT 'commentary' AS kind, cl.created_at AS ts, cl.matroid_id AS matroid_id,
                m.n, m.alpha_num, m.alpha_den, cu.display_name AS user, cl.content AS content
           FROM commentary_log cl
           LEFT JOIN users cu ON cu.id = cl.user_id
           JOIN matroids m ON m.id = cl.matroid_id
       )
       -- kind ASC tiebreak: at the same second-precision timestamp a
       -- commentary edit sorts above its matroid in this newest-first feed,
       -- since the commentary logically follows the record.
       ORDER BY ts DESC, kind ASC
       LIMIT ? OFFSET ?`,
  )
    .bind(size + 1, page * size)
    .all<ActivityItem>()
  return { items: results.slice(0, size), page, hasOlder: results.length > size }
}

export function listTokens(env: Bindings, userId: number): Promise<TokenRow[]> {
  return env.DB.prepare(
    `SELECT id, name, prefix, created_at, last_used_at, revoked_at
       FROM api_tokens WHERE user_id = ? ORDER BY id DESC`,
  )
    .bind(userId)
    .all<TokenRow>()
    .then((r) => r.results)
}

/** The user's record matroids, largest constant first, flagged when still the record. */
export function userMatroids(env: Bindings, userId: number): Promise<UserMatroidRow[]> {
  return env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.alpha_num, m.alpha_den, m.alpha_value, m.created_at,
            (m.id = (SELECT MAX(id) FROM matroids WHERE n = m.n)) AS is_current
       FROM matroids m WHERE m.submitter_user_id = ? ORDER BY m.alpha_value DESC, m.n`,
  )
    .bind(userId)
    .all<UserMatroidRow>()
    .then((r) => r.results)
}

/** One row on the /matroids listing page. */
export interface MatroidListRow {
  id: number
  n: number
  rank: number
  num_bases: number
  alpha_num: number
  alpha_den: number
  alpha_value: number
  representation_type: string
  field: string | null
  created_at: string
  submitter: string | null
  is_current: number // SQLite boolean: 1 when still the record for n
}

/** Every record-setting matroid ever stored, current and superseded. */
export function allMatroids(env: Bindings): Promise<MatroidListRow[]> {
  return env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.representation_type, m.field, m.created_at,
            u.display_name AS submitter,
            (m.id = (SELECT MAX(id) FROM matroids WHERE n = m.n)) AS is_current
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       ORDER BY m.n, m.id`,
  )
    .all<MatroidListRow>()
    .then((r) => r.results)
}

export interface RecordStatus {
  /** True when this submission set a new record for its ground-set size. */
  recorded: boolean
  /** The current record α for n after the attempt, as a reduced fraction. */
  recordAlphaNum: number
  recordAlphaDen: number
  /** Row id of the current record matroid (the new row when recorded). */
  matroidId: number
  /**
   * Only set on a tie (recorded false, equal record α): true when the
   * submission has exactly the same bases as the current record matroid,
   * false when it is a different matroid with the same constant.
   */
  tiedExact?: boolean
}

/** The current record matroid for every ground-set size that has one. */
export async function currentRecords(env: Bindings): Promise<RecordPoint[]> {
  const { results } = await env.DB.prepare(
    `SELECT id, n, rank, num_bases, alpha_num, alpha_den, alpha_value FROM matroids m
       WHERE id = (SELECT MAX(id) FROM matroids WHERE n = m.n)
       ORDER BY n`,
  ).all<RecordPoint>()
  return results
}

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  const digest = await crypto.subtle.digest('SHA-256', bytes as BufferSource)
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Canonical matroid hash. When the bases list is small its canonical JSON is
// hashed; a huge list is hashed as raw little-endian masks instead of
// materializing a many-MB string. The scheme is determined by the basis
// count, so equal matroids always hash under the same scheme.
async function basesHashOf(result: VerifiedMatroid): Promise<string> {
  if (result.basesJson !== null) return sha256Hex(result.basesJson)
  const bytes = new Uint8Array(result.basesMasks.length * 4)
  const view = new DataView(bytes.buffer)
  for (let i = 0; i < result.basesMasks.length; i++) view.setUint32(i * 4, result.basesMasks[i], true)
  return sha256Hex(bytes)
}

interface RecordRow {
  id: number
  alpha_num: number
  alpha_den: number
  bases_hash: string
}

/** Exact fraction comparison; the cross products exceed 2^63 for large basis
 * counts, so this must happen in BigInt here, not in SQLite. */
const atLeast = (aNum: number, aDen: number, bNum: number, bDen: number): boolean =>
  BigInt(aNum) * BigInt(bDen) >= BigInt(bNum) * BigInt(aDen)

// Insert only when the constant strictly exceeds every stored record for this
// ground-set size. The comparison is done exactly in JS; the insert is
// guarded by "no row for this n newer than the one we compared against"
// (optimistic concurrency, retried on the rare race). The unique
// (n, alpha_num, alpha_den) index additionally rules out duplicate rows.
export async function recordMatroid(
  env: Bindings,
  result: VerifiedMatroid,
  provenance: string | null,
  userId: number,
): Promise<RecordStatus> {
  const basesHash = await basesHashOf(result)
  const currentFor = (n: number) =>
    env.DB.prepare(
      'SELECT id, alpha_num, alpha_den, bases_hash FROM matroids WHERE n = ? ORDER BY id DESC LIMIT 1',
    )
      .bind(n)
      .first<RecordRow>()

  const notRecorded = (row: RecordRow): RecordStatus => {
    const status: RecordStatus = {
      recorded: false,
      recordAlphaNum: row.alpha_num,
      recordAlphaDen: row.alpha_den,
      matroidId: row.id,
    }
    // On a tie, distinguish "resubmitted the record matroid itself" from "a
    // different matroid with the same constant". Bases are stored
    // canonically, so matroid equality is hash equality.
    if (row.alpha_num === result.alphaNum && row.alpha_den === result.alphaDen) {
      status.tiedExact = row.bases_hash === basesHash
    }
    return status
  }

  for (let attempt = 0; attempt < 3; attempt++) {
    const row = await currentFor(result.n)
    if (row && atLeast(row.alpha_num, row.alpha_den, result.alphaNum, result.alphaDen)) {
      return notRecorded(row)
    }
    const ins = await env.DB.prepare(
      `INSERT INTO matroids (n, rank, num_bases, alpha_num, alpha_den, alpha_value,
                             max_pairs, max_counts, representation_type, representation,
                             field, bases, bases_hash, provenance, submitter_user_id)
       SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15
       WHERE NOT EXISTS (SELECT 1 FROM matroids WHERE n = ?1 AND id > ?16)`,
    )
      .bind(
        result.n,
        result.rank,
        result.numBases,
        result.alphaNum,
        result.alphaDen,
        result.alphaValue,
        JSON.stringify(result.maximizingPairs),
        result.maxCounts ? JSON.stringify(result.maxCounts) : null,
        result.representationType,
        result.representation,
        result.field,
        result.basesJson !== null && result.basesJson.length <= BASES_STORE_MAX
          ? result.basesJson
          : null,
        basesHash,
        provenance,
        userId,
        row?.id ?? 0,
      )
      .run()
    if ((ins.meta.changes ?? 0) > 0) {
      return {
        recorded: true,
        recordAlphaNum: result.alphaNum,
        recordAlphaDen: result.alphaDen,
        matroidId: ins.meta.last_row_id as number,
      }
    }
    // A concurrent submission for this n landed between our read and insert;
    // re-read and compare against it.
  }
  const row = await currentFor(result.n)
  return row
    ? notRecorded(row)
    : { recorded: false, recordAlphaNum: result.alphaNum, recordAlphaDen: result.alphaDen, matroidId: 0 }
}
