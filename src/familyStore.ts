// D1 persistence and validation for families. A family is a reviewed claim,
// not a computation: unlike concrete matroids, nothing here is machine-
// verified, so rows carry a status — proposals arrive 'pending' through the
// on-site form, and an admin must accept one before it goes live (chart
// curve, card, page). Accepted rows are what the public site renders.

import type { Bindings } from './auth'
import type { Family, FamilyPoint, FamilySeries } from './familyData'

/** Discovery dates are YYYY-MM or YYYY-MM-DD, as for matroid records. */
export const DISCOVERY_DATE_RE = /^\d{4}-(0[1-9]|1[0-2])(-(0[1-9]|[12]\d|3[01]))?$/

interface FamilyRow {
  id: number
  slug: string
  status: 'pending' | 'accepted' | 'rejected'
  name: string
  short: string
  claim: 'exact' | 'lower'
  color: string | null
  fields_json: string
  parameter: string
  formula_tex: string
  size_rank_tex: string
  supremum_num: number
  supremum_den: number
  supremum_kind: 'attained' | 'approached' | 'iterated limit'
  contributors: string
  discovery_date: string
  ai_used: number | null
  ai_model: string | null
  ai_role: string | null
  ai_chat_url: string | null
  ai_disclosure: string | null
  summary: string
  construction: string
  curve_explanation: string
  proof_status: string
  proof_url: string | null
  math_anchor: string | null
  series_json: string
  submitter_user_id: number | null
  submitted_at: string
  review_note: string | null
  submitter_name: string | null
}

const FAMILY_COLUMNS = `f.id, f.slug, f.status, f.name, f.short, f.claim, f.color,
       f.fields_json, f.parameter, f.formula_tex, f.size_rank_tex,
       f.supremum_num, f.supremum_den, f.supremum_kind,
       f.contributors, f.discovery_date, f.ai_used, f.ai_model, f.ai_role,
       f.ai_chat_url, f.ai_disclosure, f.summary, f.construction,
       f.curve_explanation, f.proof_status, f.proof_url, f.math_anchor,
       f.series_json, f.submitter_user_id, f.submitted_at, f.review_note,
       u.display_name AS submitter_name`

const parseJson = <T>(s: string, fallback: T): T => {
  try {
    return JSON.parse(s) as T
  } catch {
    return fallback
  }
}

function rowToFamily(r: FamilyRow): Family {
  return {
    id: r.id,
    slug: r.slug,
    status: r.status,
    name: r.name,
    short: r.short,
    claim: r.claim,
    color: r.color,
    fields: parseJson<number[]>(r.fields_json, []),
    parameter: r.parameter,
    formulaTex: r.formula_tex,
    sizeRankTex: r.size_rank_tex,
    supremum: { num: r.supremum_num, den: r.supremum_den },
    supremumKind: r.supremum_kind,
    contributors: r.contributors,
    discoveryDate: r.discovery_date,
    aiUsed: r.ai_used === null ? null : !!r.ai_used,
    aiModel: r.ai_model,
    aiRole: r.ai_role,
    aiChatUrl: r.ai_chat_url,
    aiDisclosure: r.ai_disclosure,
    summary: r.summary,
    construction: r.construction,
    curveExplanation: r.curve_explanation,
    proofStatus: r.proof_status,
    proofUrl: r.proof_url,
    mathAnchor: r.math_anchor,
    series: parseJson<FamilySeries[]>(r.series_json, []),
    submitterUserId: r.submitter_user_id,
    submitterName: r.submitter_name,
    submittedAt: r.submitted_at,
    reviewNote: r.review_note,
  }
}

/** The live catalog: accepted families, oldest first (stable chart order). */
export async function acceptedFamilies(env: Bindings): Promise<Family[]> {
  const { results } = await env.DB.prepare(
    `SELECT ${FAMILY_COLUMNS} FROM families f
       LEFT JOIN users u ON u.id = f.submitter_user_id
       WHERE f.status = 'accepted' ORDER BY f.id`,
  ).all<FamilyRow>()
  return results.map(rowToFamily)
}

export async function pendingFamilies(env: Bindings): Promise<Family[]> {
  const { results } = await env.DB.prepare(
    `SELECT ${FAMILY_COLUMNS} FROM families f
       LEFT JOIN users u ON u.id = f.submitter_user_id
       WHERE f.status = 'pending' ORDER BY f.id`,
  ).all<FamilyRow>()
  return results.map(rowToFamily)
}

export async function familyBySlug(env: Bindings, slug: string): Promise<Family | null> {
  const row = await env.DB.prepare(
    `SELECT ${FAMILY_COLUMNS} FROM families f
       LEFT JOIN users u ON u.id = f.submitter_user_id
       WHERE f.slug = ?`,
  )
    .bind(slug)
    .first<FamilyRow>()
  return row ? rowToFamily(row) : null
}

/** Admin status is read fresh from D1 where it matters, never from the
 * session snapshot — flipping the bit takes effect immediately. */
export async function isAdmin(env: Bindings, userId: number | null): Promise<boolean> {
  if (userId === null) return false
  const row = await env.DB.prepare('SELECT is_admin FROM users WHERE id = ?')
    .bind(userId)
    .first<{ is_admin: number }>()
  return !!row?.is_admin
}

// ---------------------------------------------------------------------------
// Proposal validation. Pure functions (no D1), exercised by test-families.mjs.

export interface FamilyProposal {
  name: string
  short: string
  claim: 'exact' | 'lower'
  parameter: string
  formulaTex: string
  sizeRankTex: string
  supremum: { num: number; den: number }
  supremumKind: 'attained' | 'approached' | 'iterated limit'
  summary: string
  construction: string
  curveExplanation: string
  proofStatus: string
  proofUrl: string | null
  contributors: string
  discoveryDate: string
  aiUsed: boolean
  aiModel: string | null
  aiRole: string | null
  aiChatUrl: string | null
  series: FamilySeries[]
}

const MAX_SERIES = 12
const MAX_POINTS = 400

/** "a/b" or an integer, exactly — decimals are refused (a family claim is
 * an exact value). Returns the reduced fraction. */
export function parseFraction(text: string): { num: number; den: number } | { error: string } {
  const m = /^(\d{1,9})(?:\s*\/\s*([1-9]\d{0,8}))?$/.exec(text.trim())
  if (!m) return { error: `expected an exact fraction like "4/3", got ${JSON.stringify(text)}` }
  let num = Number(m[1])
  let den = m[2] ? Number(m[2]) : 1
  const gcd = (a: number, b: number): number => (b ? gcd(b, a % b) : a)
  const g = gcd(num, den)
  num /= g
  den /= g
  return { num, den }
}

/** Parse and validate the plotted-members JSON from the proposal form:
 *   [{"label": "q = 2", "points": [{"parameter": "d = 3", "n": 10,
 *     "rank": 7, "alpha": "6/7", "field": 2}, ...]}, ...]
 * Values are exact fractions; every point must respect the HSW bound. */
export function parseSeries(text: string): FamilySeries[] | { error: string } {
  let raw: unknown
  try {
    raw = JSON.parse(text)
  } catch (e) {
    return { error: `plotted members must be valid JSON (${(e as Error).message})` }
  }
  if (!Array.isArray(raw) || raw.length === 0) {
    return { error: 'plotted members must be a nonempty JSON list of series' }
  }
  if (raw.length > MAX_SERIES) return { error: `at most ${MAX_SERIES} series` }
  const series: FamilySeries[] = []
  let totalPoints = 0
  for (let si = 0; si < raw.length; si++) {
    const s = raw[si] as { label?: unknown; points?: unknown }
    const where = `series ${si + 1}`
    if (typeof s !== 'object' || s === null || Array.isArray(s)) {
      return { error: `${where}: expected {"label": ..., "points": [...]}` }
    }
    const label = typeof s.label === 'string' ? s.label.trim() : ''
    if (label === '' || label.length > 80) {
      return { error: `${where}: "label" must be a string of at most 80 characters` }
    }
    if (!Array.isArray(s.points) || s.points.length === 0) {
      return { error: `${where} ("${label}"): "points" must be a nonempty list` }
    }
    const points: FamilyPoint[] = []
    for (let pi = 0; pi < s.points.length; pi++) {
      const p = s.points[pi] as {
        parameter?: unknown
        n?: unknown
        rank?: unknown
        alpha?: unknown
        field?: unknown
      }
      const pwhere = `${where} ("${label}"), point ${pi + 1}`
      if (typeof p !== 'object' || p === null || Array.isArray(p)) {
        return { error: `${pwhere}: expected {"parameter", "n", "rank", "alpha"}` }
      }
      const parameter = typeof p.parameter === 'string' ? p.parameter.trim() : ''
      if (parameter === '' || parameter.length > 80) {
        return { error: `${pwhere}: "parameter" must be a string of at most 80 characters` }
      }
      if (typeof p.n !== 'number' || !Number.isInteger(p.n) || p.n < 1 || p.n > 1_000_000) {
        return { error: `${pwhere}: "n" must be an integer between 1 and 1000000` }
      }
      if (typeof p.rank !== 'number' || !Number.isInteger(p.rank) || p.rank < 0 || p.rank > p.n) {
        return { error: `${pwhere}: "rank" must be an integer between 0 and n` }
      }
      if (typeof p.alpha !== 'string') {
        return { error: `${pwhere}: "alpha" must be an exact fraction string like "6/7"` }
      }
      const frac = parseFraction(p.alpha)
      if ('error' in frac) return { error: `${pwhere}: ${frac.error}` }
      if (frac.num > 2 * frac.den) {
        return {
          error: `${pwhere}: α = ${p.alpha} exceeds 2, contradicting the Huh–Schröter–Wang bound`,
        }
      }
      let field: number | undefined
      if (p.field !== undefined && p.field !== null) {
        if (typeof p.field !== 'number' || !Number.isInteger(p.field) || p.field < 2) {
          return { error: `${pwhere}: "field" must be an integer ≥ 2 when given` }
        }
        field = p.field
      }
      totalPoints++
      if (totalPoints > MAX_POINTS) return { error: `at most ${MAX_POINTS} points in total` }
      const pt: FamilyPoint = { parameter, n: p.n, rank: p.rank, num: frac.num, den: frac.den }
      if (field !== undefined) pt.field = field
      points.push(pt)
    }
    series.push({ id: `s${si + 1}`, label, points })
  }
  return series
}

/** Validate a raw family-proposal form body into a FamilyProposal. Every
 * substantive field is required — a family enters review, not a scratchpad —
 * including the full discovery record, as for matroid record entries. */
export function parseFamilyProposal(
  raw: Record<string, unknown>,
): FamilyProposal | { error: string } {
  const text = (v: unknown, max: number): string | null =>
    typeof v === 'string' && v.trim() !== '' ? v.trim().slice(0, max) : null
  const req = (v: unknown, max: number, label: string): string | { error: string } =>
    text(v, max) ?? { error: `${label} is required` }

  const fields = {
    name: req(raw.name, 120, 'the family name'),
    short: req(raw.short, 40, 'the short name (chart legend)'),
    parameter: req(raw.parameter, 200, 'the parameter description'),
    formulaTex: req(raw.formula_tex, 500, 'the formula'),
    sizeRankTex: req(raw.size_rank_tex, 500, 'the size and rank formula'),
    summary: req(raw.summary, 1000, 'the summary'),
    construction: req(raw.construction, 4000, 'the construction'),
    curveExplanation: req(raw.curve_explanation, 4000, 'what the curve shows'),
    proofStatus: req(raw.proof_status, 2000, 'the proof status'),
    contributors: req(raw.contributors, 500, 'discovered by'),
    discoveryDate: req(raw.discovery_date, 10, 'the discovery date'),
  }
  for (const v of Object.values(fields)) {
    if (typeof v === 'object') return v
  }
  const f = fields as Record<keyof typeof fields, string>

  const claim = raw.claim === 'exact' || raw.claim === 'lower' ? raw.claim : null
  if (claim === null) {
    return { error: 'the claim type must be "exact" (proved value) or "lower" (certified lower bound)' }
  }
  const supremumKind =
    raw.supremum_kind === 'attained' ||
    raw.supremum_kind === 'approached' ||
    raw.supremum_kind === 'iterated limit'
      ? raw.supremum_kind
      : null
  if (supremumKind === null) {
    return { error: 'the supremum kind must be attained, approached, or iterated limit' }
  }
  const supremumText = text(raw.supremum, 40)
  if (supremumText === null) return { error: 'the supremum is required' }
  const supremum = parseFraction(supremumText)
  if ('error' in supremum) return { error: `supremum: ${supremum.error}` }
  if (supremum.num > 2 * supremum.den) {
    return { error: 'the supremum exceeds 2, contradicting the Huh–Schröter–Wang bound' }
  }

  if (!DISCOVERY_DATE_RE.test(f.discoveryDate)) {
    return { error: 'discovery date must be YYYY-MM or YYYY-MM-DD' }
  }

  const proofUrl = text(raw.proof_url, 500)
  if (proofUrl !== null && !/^https?:\/\//.test(proofUrl)) {
    return { error: 'the proof link must be an http(s) URL' }
  }

  const aiUsed = raw.ai_used === 'yes' ? true : raw.ai_used === 'no' ? false : null
  if (aiUsed === null) return { error: 'the AI-use declaration (yes or no) is required' }
  const aiModel = text(raw.ai_model, 200)
  const aiRole = text(raw.ai_role, 1000)
  if (aiUsed && (aiModel === null || aiRole === null)) {
    return {
      error: 'when AI use is declared, the model/version and a brief role description are required',
    }
  }
  const aiChatUrl = text(raw.ai_chat_url, 500)
  if (aiChatUrl !== null && !/^https?:\/\//.test(aiChatUrl)) {
    return { error: 'the AI chat link must be an http(s) URL' }
  }

  const seriesText = typeof raw.series === 'string' ? raw.series : ''
  if (seriesText.length > 100_000) return { error: 'plotted members: too large' }
  const series = parseSeries(seriesText)
  if ('error' in series) return { error: series.error }

  return {
    name: f.name,
    short: f.short,
    claim,
    parameter: f.parameter,
    formulaTex: f.formulaTex,
    sizeRankTex: f.sizeRankTex,
    supremum,
    supremumKind,
    summary: f.summary,
    construction: f.construction,
    curveExplanation: f.curveExplanation,
    proofStatus: f.proofStatus,
    proofUrl,
    contributors: f.contributors,
    discoveryDate: f.discoveryDate,
    aiUsed,
    aiModel: aiUsed ? aiModel : null,
    aiRole: aiUsed ? aiRole : null,
    aiChatUrl,
    series,
  }
}

export function slugify(name: string): string {
  const s = name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/, '')
  return s || 'family'
}

// ---------------------------------------------------------------------------
// Writes.

/** Insert a proposal as a pending row. The slug is derived from the name and
 * uniquified with a numeric suffix on collision. */
export async function submitFamily(
  env: Bindings,
  p: FamilyProposal,
  userId: number,
): Promise<{ slug: string }> {
  const base = slugify(p.name)
  for (let attempt = 0; attempt < 20; attempt++) {
    const slug = attempt === 0 ? base : `${base}-${attempt + 1}`
    try {
      await env.DB.prepare(
        `INSERT INTO families
           (slug, status, name, short, claim, parameter, formula_tex, size_rank_tex,
            supremum_num, supremum_den, supremum_kind, contributors, discovery_date,
            ai_used, ai_model, ai_role, ai_chat_url, summary, construction,
            curve_explanation, proof_status, proof_url, series_json, submitter_user_id)
         VALUES (?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
        .bind(
          slug,
          p.name,
          p.short,
          p.claim,
          p.parameter,
          p.formulaTex,
          p.sizeRankTex,
          p.supremum.num,
          p.supremum.den,
          p.supremumKind,
          p.contributors,
          p.discoveryDate,
          p.aiUsed ? 1 : 0,
          p.aiModel,
          p.aiRole,
          p.aiChatUrl,
          p.summary,
          p.construction,
          p.curveExplanation,
          p.proofStatus,
          p.proofUrl,
          JSON.stringify(p.series),
          userId,
        )
        .run()
      return { slug }
    } catch (e) {
      if (!/UNIQUE/i.test(String(e))) throw e
    }
  }
  throw new Error('could not allocate a unique family slug')
}

/** The curated palette; acceptance picks the first color no accepted family
 * uses, falling back to a hue spun from the row id. */
const FAMILY_PALETTE = [
  '#8c3d2f',
  '#176b72',
  '#6d4c93',
  '#b5652a',
  '#34745b',
  '#a1487d',
  '#5b7a2e',
  '#2f5d8c',
  '#8a6d1f',
  '#7a4a2b',
]

export async function reviewFamily(
  env: Bindings,
  familyId: number,
  action: 'accept' | 'reject',
  adminId: number,
  note: string | null,
): Promise<boolean> {
  let color: string | null = null
  if (action === 'accept') {
    const { results } = await env.DB.prepare(
      `SELECT color FROM families WHERE status = 'accepted' AND color IS NOT NULL`,
    ).all<{ color: string }>()
    const used = new Set(results.map((r) => r.color))
    color = FAMILY_PALETTE.find((c) => !used.has(c)) ?? `hsl(${(familyId * 137) % 360} 45% 38%)`
  }
  const res = await env.DB.prepare(
    `UPDATE families
       SET status = ?, color = COALESCE(?, color), reviewed_by = ?,
           reviewed_at = CURRENT_TIMESTAMP, review_note = ?
       WHERE id = ? AND status = 'pending'`,
  )
    .bind(action === 'accept' ? 'accepted' : 'rejected', color, adminId, note, familyId)
    .run()
  return (res.meta.changes ?? 0) > 0
}
