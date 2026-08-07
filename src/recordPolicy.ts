// What counts as a record (decided with Chris Eur, August 2026). The record
// book tracks exactly two things:
//
//   * a field record for each of GF(2), GF(3), GF(4), GF(5), GF(7): the best
//     verified α over that field, held until strictly beaten;
//   * the 4/3 club: every concrete matroid reaching α ≥ 4/3, with any
//     description — membership is permanent.
//
// Records have nothing to do with rank or ground-set size. This module is
// pure (no D1, no worker imports) so `npm test` can exercise it directly;
// src/store.ts applies it.

export const RECORD_FIELDS = [2, 3, 4, 5, 7] as const

/** Exact fraction comparison a/b ≥ c/d; the cross products exceed 2^63 for
 * large basis counts, so this must happen in BigInt, never in SQLite. */
export const atLeast = (aNum: number, aDen: number, bNum: number, bDen: number): boolean =>
  BigInt(aNum) * BigInt(bDen) >= BigInt(bNum) * BigInt(aDen)

/** Does α reach the 4/3 challenge? */
export const reachesGoal = (num: number, den: number): boolean => atLeast(num, den, 4, 3)

/** The field records a verified matrix contends for: its own field when it
 * is on the menu, plus GF(4) for a GF(2) matrix — GF(2) ⊂ GF(4) is the one
 * subfield pair among the five, so a binary matrix proves GF(4)
 * representability too. ℚ and off-menu fields contend for nothing (they can
 * still enter the club). `field` is the verifier's field string: 'Q', or
 * the field order as decimal text. */
export function candidateFields(field: string | null): number[] {
  if (field === null || field === 'Q') return []
  const q = Number(field)
  if (q === 2) return [2, 4]
  return (RECORD_FIELDS as readonly number[]).includes(q) ? [q] : []
}

/** Does a submission take the field record over the standing one? Strictly
 * greater; an empty slot (fresh database) is taken by any positively
 * correlated matroid. */
export function beatsStanding(
  subNum: number,
  subDen: number,
  standing: { alphaNum: number; alphaDen: number } | null,
): boolean {
  if (standing === null) return !atLeast(1, 1, subNum, subDen)
  return !atLeast(standing.alphaNum, standing.alphaDen, subNum, subDen)
}
