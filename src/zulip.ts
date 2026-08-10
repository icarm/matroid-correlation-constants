// Posts a Zulip message when a submission enters the record book — takes a
// field record over GF(2)/GF(3)/GF(4)/GF(5)/GF(7) and/or joins the 4/3 club.
//
// Delivery uses Zulip's Slack-compatible incoming webhook
// (`/api/v1/external/slack_incoming`), the same scheme as the sibling
// ruzsa-genus-one: a single secret URL with the api_key, stream, and topic
// baked in, to which we POST `{ "text": <markdown> }`. The URL lives in the
// ZULIP_WEBHOOK_URL secret; when it is unset (e.g. local dev) notification
// is silently skipped.

import type { Bindings } from './auth'
import type { RecordStatus } from './store'
import type { VerifiedMatroid } from './verify'

// Send `text` as a Zulip message via the incoming webhook. Returns true on a
// 2xx response. Never throws: delivery is best-effort and runs off the
// request path.
async function send(url: string, text: string): Promise<boolean> {
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text }),
    })
    if (!res.ok) {
      console.error(`Zulip webhook returned ${res.status}: ${await res.text()}`)
      return false
    }
    return true
  } catch (err) {
    console.error('Zulip webhook request failed:', err)
    return false
  }
}

const frac = (num: number, den: number): string => (den === 1 ? `${num}` : `${num}/${den}`)

/** User-supplied text lands inside Zulip markdown link labels and bold
 * spans; strip the characters that could break out of them. */
const plain = (s: string): string => s.replace(/[[\]()`*\n]/g, ' ').trim()

// Notify Zulip that a submission entered the record book. The dethroned
// holder of each field record taken is the newest title row for that field
// belonging to another matroid (the new holder's row is now the newest).
// No-op when the webhook is unconfigured or nothing was recorded.
//
// Intended to be called via `ctx.waitUntil(...)` so neither the history
// lookups nor delivery blocks the response to the submitter.
export async function notifyNewRecord(
  env: Bindings,
  record: RecordStatus,
  result: VerifiedMatroid,
  name: string | null,
  submitter: string | null,
  baseUrl: string,
): Promise<void> {
  const url = env.ZULIP_WEBHOOK_URL
  if (!url || !record.recorded) return

  const fieldsLabel = record.fieldsTaken.map((f) => `GF(${f})`).join(' and ')
  const heading =
    record.fieldsTaken.length > 0 ? `New ${fieldsLabel} record` : 'New 4/3 club member'
  const link = `${baseUrl}/matroid/${record.matroidId}`
  const linkText = (name && plain(name)) || `matroid #${record.matroidId}`
  const who = submitter && plain(submitter) ? `, submitted by **${plain(submitter)}**` : ''

  const previous: string[] = []
  for (const field of record.fieldsTaken) {
    const prev = await env.DB.prepare(
      `SELECT m.id, m.alpha_num, m.alpha_den
         FROM record_titles t JOIN matroids m ON m.id = t.matroid_id
        WHERE t.field = ? AND t.matroid_id != ?
        ORDER BY t.id DESC LIMIT 1`,
    )
      .bind(field, record.matroidId)
      .first<{ id: number; alpha_num: number; alpha_den: number }>()
    previous.push(
      prev
        ? `GF(${field}) was ᾱ = ${frac(prev.alpha_num, prev.alpha_den)} ([matroid #${prev.id}](${baseUrl}/matroid/${prev.id}))`
        : `GF(${field}) had no record holder`,
    )
  }
  const prevText = previous.length > 0 ? ` Previously: ${previous.join('; ')}.` : ''

  const text =
    `:trophy: **${heading}: ᾱ = ${frac(result.alphaNum, result.alphaDen)} ≈ ${result.alphaValue.toFixed(5)}** — ` +
    `[${linkText}](${link}) with |E| = ${result.n}, rank ${result.rank}, ` +
    `${result.numBases.toLocaleString('en-US')} bases${who}.${prevText}` +
    (record.club ? '\n:tada: It reaches ᾱ ≥ 4/3 — a concrete matroid at the record to beat!' : '')

  await send(url, text)
}
