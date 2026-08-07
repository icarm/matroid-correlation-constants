// The family model: the shapes family rows are mapped into (familyStore.ts)
// and the transformation the explorer chart consumes. The data itself lives
// in the D1 `families` table (seeded by migrations/0008_families.sql);
// proposals arrive through the on-site form and go live when an admin
// accepts them.
//
// Formula and prose strings contain TeX (rendered by MathJax on the family
// pages); they are stored as plain text and rendered HTML-escaped.

export interface FamilyPoint {
  parameter: string
  n: number
  rank: number
  num: number
  den: number
  /** For the chart's field filter: the member's own field, when it has one. */
  field?: number
}

export interface FamilySeries {
  id: string
  label: string
  points: FamilyPoint[]
}

export interface Family {
  id: number // D1 row id
  slug: string
  status: 'pending' | 'accepted' | 'rejected'
  name: string
  short: string
  claim: 'exact' | 'lower'
  color: string | null // assigned at acceptance
  /** Fields with verified members, for the chart's field filter. */
  fields: number[]
  parameter: string
  formulaTex: string
  sizeRankTex: string
  supremum: { num: number; den: number }
  supremumKind: 'attained' | 'approached' | 'iterated limit'
  contributors: string
  discoveryDate: string
  aiUsed: boolean | null
  aiModel: string | null
  aiRole: string | null
  aiChatUrl: string | null
  /** Handwritten disclosure prose (curated rows); proposals compose one
   * from the structured fields. */
  aiDisclosure: string | null
  summary: string
  construction: string
  curveExplanation: string
  proofStatus: string
  proofUrl: string | null
  mathAnchor: string | null
  series: FamilySeries[]
  submitterUserId: number | null
  submitterName: string | null
  submittedAt: string
  reviewNote: string | null
}

export const fmtFrac = (num: number, den: number): string =>
  den === 1 ? String(num) : `${num}/${den}`

/** The families in the shape public/chart.js consumes, injected into the
 * landing page as JSON alongside the record points. */
export function familiesChartData(families: Family[]): unknown {
  return families.map((f) => ({
    id: f.slug,
    name: f.name,
    short: f.short,
    claim: f.claim,
    color: f.color,
    fields: f.fields,
    series: f.series.map((s) => ({
      id: s.id,
      label: s.label,
      points: s.points.map((p) => ({
        parameter: p.parameter,
        n: p.n,
        rank: p.rank,
        field: p.field ?? null,
        exact: { label: fmtFrac(p.num, p.den), value: p.num / p.den },
      })),
    })),
  }))
}
