// D1 persistence for the record book. Two append-only tables cooperate:
// matroids holds every matroid that ever entered the book (superseded
// record-holders stay as history), and record_titles records each title
// taken — a field record for one of GF(2)/GF(3)/GF(4)/GF(5)/GF(7), or
// membership in the 4/3 club (field IS NULL). Field records only ever
// strictly increase, so the current holder is the title row with the
// largest id for that field; club membership is permanent. What counts as
// a record lives in src/recordPolicy.ts.

import type { Bindings } from './auth'
import type { RecordPoint, UserMatroidRow } from './pages'
import { beatsStanding, candidateFields, reachesGoal } from './recordPolicy'
import { VERIFIER_VERSION, type VerifiedMatroid } from './verify'

/** Structured discovery metadata accompanying a submission (all optional;
 * validated in the route layer). Mirrors the discovery-record fields of the
 * draft site's submission schema: discovery is distinct from submission, and
 * AI use is disclosed as data, not prose. */
export interface SubmissionMeta {
  name: string | null
  discoverers: string | null
  discoveryDate: string | null
  aiUsed: boolean | null
  aiModel: string | null
  aiRole: string | null
  aiChatUrl: string | null
  citation: string | null
  provenance: string | null
}

// Canonical bases lists are stored only up to this size; the entry is always
// recomputable from its stored representation. (Keeps rows well under D1's
// per-value limits even for matrix submissions with tens of thousands of bases.)
const BASES_STORE_MAX = 200_000

// The titles a matroid currently holds, as one GROUP_CONCAT string: 'club'
// for 4/3-club membership, the field order for a field record it still
// holds. NULL when the row holds nothing (a superseded record-holder).
// Shared by every listing query; pages.ts formats it for display.
const CURRENT_TITLES_SQL = `
  (SELECT GROUP_CONCAT(CASE WHEN t.field IS NULL THEN 'club' ELSE CAST(t.field AS TEXT) END)
     FROM record_titles t
    WHERE t.matroid_id = m.id
      AND (t.field IS NULL
           OR t.id = (SELECT MAX(id) FROM record_titles t2 WHERE t2.field = t.field)))`

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
  cert_field: string | null
  cert_matrix: string | null
  bases: string | null
  name: string | null
  discoverers: string | null
  discovery_date: string | null
  ai_used: number | null // SQLite boolean; NULL = undisclosed
  ai_model: string | null
  ai_role: string | null
  ai_chat_url: string | null
  citation: string | null
  provenance: string | null
  created_at: string
  submitter_name: string | null
  titles: string | null // current titles ('club' and/or field orders), CSV
  past_fields: string | null // every field record ever held, CSV
}

export async function loadMatroid(env: Bindings, id: number): Promise<MatroidView | null> {
  return env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.max_pairs, m.max_counts, m.representation_type, m.representation,
            m.field, m.cert_field, m.cert_matrix, m.bases,
            m.name, m.discoverers, m.discovery_date, m.ai_used, m.ai_model,
            m.ai_role, m.ai_chat_url, m.citation, m.provenance,
            m.created_at,
            u.display_name AS submitter_name,
            ${CURRENT_TITLES_SQL} AS titles,
            (SELECT GROUP_CONCAT(CAST(t.field AS TEXT)) FROM record_titles t
              WHERE t.matroid_id = m.id AND t.field IS NOT NULL) AS past_fields
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       WHERE m.id = ?`,
  )
    .bind(id)
    .first<MatroidView>()
}

// One row in the recent-activity feed: a matroid that entered the record
// book, with the titles it took. (Commentary was switched off in August
// 2026; its dormant tables remain in D1, and its feed arm went with it.)
export interface ActivityItem {
  ts: string
  matroid_id: number
  n: number
  alpha_num: number
  alpha_den: number
  user: string | null
  titles: string | null // every title this matroid ever took, CSV
}

export const ACTIVITY_PAGE_SIZE = 30

// Recent activity, newest first, paginated. `hasOlder` reports whether a
// further page exists (we fetch one extra row to find out).
export async function recentActivity(
  env: Bindings,
  page = 0,
): Promise<{ items: ActivityItem[]; page: number; hasOlder: boolean }> {
  const size = ACTIVITY_PAGE_SIZE
  const { results } = await env.DB.prepare(
    `SELECT m.created_at AS ts, m.id AS matroid_id, m.n, m.alpha_num, m.alpha_den,
            u.display_name AS user,
            (SELECT GROUP_CONCAT(CASE WHEN t.field IS NULL THEN 'club' ELSE CAST(t.field AS TEXT) END)
               FROM record_titles t WHERE t.matroid_id = m.id) AS titles
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       ORDER BY ts DESC LIMIT ? OFFSET ?`,
  )
    .bind(size + 1, page * size)
    .all<ActivityItem>()
  return { items: results.slice(0, size), page, hasOlder: results.length > size }
}

/** The user's record matroids, largest constant first, with current titles. */
export function userMatroids(env: Bindings, userId: number): Promise<UserMatroidRow[]> {
  return env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.alpha_num, m.alpha_den, m.alpha_value, m.created_at,
            ${CURRENT_TITLES_SQL} AS titles
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
  cert_field: string | null
  created_at: string
  submitter: string | null
  titles: string | null // current titles ('club' and/or field orders), CSV
}

/** Every matroid ever to enter the record book, current holders and history. */
export function allMatroids(env: Bindings): Promise<MatroidListRow[]> {
  return env.DB.prepare(
    `SELECT m.id, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.representation_type, m.field, m.cert_field, m.created_at,
            u.display_name AS submitter,
            ${CURRENT_TITLES_SQL} AS titles
       FROM matroids m LEFT JOIN users u ON u.id = m.submitter_user_id
       ORDER BY m.n, m.id`,
  )
    .all<MatroidListRow>()
    .then((r) => r.results)
}

/** A standing field record, for "didn't beat it" messaging. */
export interface StandingRecord {
  field: number
  matroidId: number
  alphaNum: number
  alphaDen: number
}

export interface RecordStatus {
  /** True when this submission entered the record book (a row was saved and
   * it took at least one title). */
  recorded: boolean
  /** Row id of the saved matroid; on a resubmission (tiedExact) the id of
   * the already-stored row; 0 when nothing points anywhere. */
  matroidId: number
  /** The field records this submission took — or, with needsDiscovery, the
   * ones it would take. */
  fieldsTaken: number[]
  /** Entered (or, with needsDiscovery, would enter) the 4/3 club. */
  club: boolean
  /**
   * Set when the submission would have entered the record book but was not
   * saved because it lacked a complete discovery record (discoverers, date,
   * and an AI-use declaration). Verification itself succeeded; resubmitting
   * with the attribution fields records it.
   */
  needsDiscovery?: boolean
  /** When not recorded: the standing records over the submission's candidate
   * fields, so the result page can say what there was to beat. */
  standing?: StandingRecord[]
  /** Not recorded because it never contended: no matrix over a menu field
   * (GF(2)/GF(3)/GF(4)/GF(5)/GF(7)) and below the 4/3 club threshold. */
  noCandidateField?: boolean
  /** This exact matroid (canonical-hash equality) is already in the record
   * book as row `matroidId`; the submission added no new title. */
  tiedExact?: boolean
  /**
   * Set when a submission carried new information about a stored matroid: a
   * matrix over a field the stored row was not verified over, attached to it
   * as a representability certificate.
   */
  certificateAttached?: boolean
}

/** Everything currently in the record book, one point per matroid: the five
 * field-record holders plus every 4/3-club member. History rows that hold
 * no title do not plot. */
export async function recordPoints(env: Bindings): Promise<RecordPoint[]> {
  const { results } = await env.DB.prepare(
    `SELECT m.id, m.name, m.n, m.rank, m.num_bases, m.alpha_num, m.alpha_den, m.alpha_value,
            m.field, m.cert_field, t.field AS title_field
       FROM record_titles t JOIN matroids m ON m.id = t.matroid_id
      WHERE t.field IS NULL
         OR t.id = (SELECT MAX(id) FROM record_titles t2 WHERE t2.field = t.field)
      ORDER BY m.n, m.id`,
  ).all<{
    id: number
    name: string | null
    n: number
    rank: number
    num_bases: number
    alpha_num: number
    alpha_den: number
    alpha_value: number
    field: string | null
    cert_field: string | null
    title_field: number | null
  }>()
  // One matroid can hold several titles (GF(2) and GF(4); a record and the
  // club); collapse to one plot point carrying them all.
  const byId = new Map<number, RecordPoint>()
  for (const r of results) {
    let p = byId.get(r.id)
    if (!p) {
      p = {
        id: r.id,
        name: r.name,
        n: r.n,
        rank: r.rank,
        num_bases: r.num_bases,
        alpha_num: r.alpha_num,
        alpha_den: r.alpha_den,
        alpha_value: r.alpha_value,
        field: r.field,
        cert_field: r.cert_field,
        recordFields: [],
        club: false,
      }
      byId.set(r.id, p)
    }
    if (r.title_field === null) p.club = true
    else p.recordFields.push(r.title_field)
  }
  for (const p of byId.values()) p.recordFields.sort((a, b) => a - b)
  return [...byId.values()]
}

interface StandingRow {
  title_id: number
  matroid_id: number
  alpha_num: number
  alpha_den: number
  bases_hash: string
}

interface ExistingRow {
  id: number
  field: string | null
  cert_field: string | null
}

// Enter the record book when the submission strictly beats a standing field
// record it contends for, or reaches the 4/3 club. Comparison is done
// exactly in JS BigInt; each title insert is guarded by "the record I
// compared against is still the newest" (optimistic concurrency, retried on
// the rare race). Matroid identity is canonical-hash equality, so the same
// matroid resubmitted attaches to its existing row instead of duplicating.
export async function recordMatroid(
  env: Bindings,
  result: VerifiedMatroid,
  meta: SubmissionMeta,
  userId: number,
): Promise<RecordStatus> {
  const club = reachesGoal(result.alphaNum, result.alphaDen)
  const candidates = candidateFields(result.field)
  const none: RecordStatus = { recorded: false, matroidId: 0, fieldsTaken: [], club: false }

  // Never a contender: no matrix over a menu field, and below the club bar.
  // Verification itself stays open to any matroid.
  if (!club && candidates.length === 0) return { ...none, noCandidateField: true }

  // Anything entering the record book must carry a complete discovery
  // record — discoverers, a discovery date, and an explicit AI-use
  // declaration (with model and role when AI was used). Casual verification
  // stays free-form; the permanent catalog does not.
  const discoveryComplete =
    meta.discoverers !== null &&
    meta.discoveryDate !== null &&
    meta.aiUsed !== null &&
    (meta.aiUsed === false || (meta.aiModel !== null && meta.aiRole !== null))

  const standingFor = (field: number) =>
    env.DB.prepare(
      `SELECT t.id AS title_id, m.id AS matroid_id, m.alpha_num, m.alpha_den, m.bases_hash
         FROM record_titles t JOIN matroids m ON m.id = t.matroid_id
        WHERE t.field = ? ORDER BY t.id DESC LIMIT 1`,
    )
      .bind(field)
      .first<StandingRow>()

  const existingByHash = () =>
    env.DB.prepare(
      `SELECT id, field, cert_field FROM matroids WHERE bases_hash = ? ORDER BY id LIMIT 1`,
    )
      .bind(result.basesHash)
      .first<ExistingRow>()

  // A matrix over a field the stored row is not verified over becomes a
  // representability certificate on that row (one slot; first come, first
  // kept — the guard makes it race-safe). A multi-certificate table is the
  // agreed Tier 2 follow-up.
  const attachCert = async (row: ExistingRow): Promise<boolean> => {
    if (result.representationType !== 'matrix' || result.field === null) return false
    if (row.cert_field !== null || row.field === result.field) return false
    const upd = await env.DB.prepare(
      `UPDATE matroids SET cert_field = ?, cert_matrix = ? WHERE id = ? AND cert_field IS NULL`,
    )
      .bind(result.field, result.representation, row.id)
      .run()
    return (upd.meta.changes ?? 0) > 0
  }

  const standingStatus = (standing: Map<number, StandingRow | null>): StandingRecord[] => {
    const out: StandingRecord[] = []
    for (const [field, row] of standing) {
      if (row) {
        out.push({
          field,
          matroidId: row.matroid_id,
          alphaNum: row.alpha_num,
          alphaDen: row.alpha_den,
        })
      }
    }
    return out
  }

  for (let attempt = 0; attempt < 3; attempt++) {
    const standing = new Map<number, StandingRow | null>()
    for (const f of candidates) standing.set(f, (await standingFor(f)) ?? null)
    const won = candidates.filter((f) => {
      const cur = standing.get(f) ?? null
      return beatsStanding(
        result.alphaNum,
        result.alphaDen,
        cur === null ? null : { alphaNum: cur.alpha_num, alphaDen: cur.alpha_den },
      )
    })

    if (won.length === 0 && !club) {
      const status: RecordStatus = { ...none, standing: standingStatus(standing) }
      const existing = await existingByHash()
      if (existing) {
        status.tiedExact = true
        status.matroidId = existing.id
        if (await attachCert(existing)) status.certificateAttached = true
      }
      return status
    }

    if (!discoveryComplete) {
      return { recorded: false, matroidId: 0, fieldsTaken: won, club, needsDiscovery: true }
    }

    const existing = await existingByHash()
    let matroidId: number
    let insertedRow = false
    let certificateAttached = false
    if (existing) {
      matroidId = existing.id
      certificateAttached = await attachCert(existing)
    } else {
      const ins = await env.DB.prepare(
        `INSERT INTO matroids (n, rank, num_bases, alpha_num, alpha_den, alpha_value,
                               max_pairs, max_counts, representation_type, representation,
                               field, bases, bases_hash, provenance, submitter_user_id,
                               name, discoverers, discovery_date, ai_used, ai_model,
                               ai_role, ai_chat_url, citation, verifier_version)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15,
                 ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24)`,
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
          result.basesHash,
          meta.provenance,
          userId,
          meta.name,
          meta.discoverers,
          meta.discoveryDate,
          meta.aiUsed === null ? null : meta.aiUsed ? 1 : 0,
          meta.aiModel,
          meta.aiRole,
          meta.aiChatUrl,
          meta.citation,
          VERIFIER_VERSION,
        )
        .run()
      matroidId = ins.meta.last_row_id as number
      insertedRow = true
    }

    const taken: number[] = []
    for (const f of won) {
      const expected = standing.get(f)?.title_id ?? 0
      // The NOT EXISTS arm can only matter on inconsistent data (a holder
      // cannot strictly beat its own α), but it turns what would be a
      // unique-index violation into a clean no-op.
      const ins = await env.DB.prepare(
        `INSERT INTO record_titles (matroid_id, field)
         SELECT ?1, ?2
          WHERE (SELECT COALESCE(MAX(id), 0) FROM record_titles WHERE field = ?2) = ?3
            AND NOT EXISTS (SELECT 1 FROM record_titles WHERE matroid_id = ?1 AND field = ?2)`,
      )
        .bind(matroidId, f, expected)
        .run()
      if ((ins.meta.changes ?? 0) > 0) taken.push(f)
    }
    let joinedClub = false
    if (club) {
      const ins = await env.DB.prepare(
        `INSERT INTO record_titles (matroid_id, field)
         SELECT ?1, NULL
          WHERE NOT EXISTS (SELECT 1 FROM record_titles WHERE matroid_id = ?1 AND field IS NULL)`,
      )
        .bind(matroidId)
        .run()
      joinedClub = (ins.meta.changes ?? 0) > 0
    }

    if (taken.length > 0 || joinedClub) {
      const status: RecordStatus = { recorded: true, matroidId, fieldsTaken: taken, club: joinedClub }
      if (certificateAttached) status.certificateAttached = true
      return status
    }

    if (!insertedRow) {
      // The exact matroid is already in the book and this submission granted
      // it nothing new: a resubmission (possibly with a fresh certificate).
      const status: RecordStatus = { ...none, matroidId, tiedExact: true }
      if (certificateAttached) status.certificateAttached = true
      return status
    }
    // Every guarded title insert lost a race to a concurrent submission; the
    // row created above holds nothing, so remove it and re-evaluate against
    // the new records.
    await env.DB.prepare(`DELETE FROM matroids WHERE id = ?`).bind(matroidId).run()
  }

  // Retries exhausted: report whatever stands now.
  const standing = new Map<number, StandingRow | null>()
  for (const f of candidates) standing.set(f, (await standingFor(f)) ?? null)
  return { ...none, standing: standingStatus(standing) }
}
