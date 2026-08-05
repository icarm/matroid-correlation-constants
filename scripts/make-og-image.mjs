// Render public/og.png — the social-preview (Open Graph) card at the standard
// 1200x630: for now, simply the site icon (public/favicon.svg) centered on the
// icon's own background color.
//
//   node scripts/make-og-image.mjs
import fs from 'node:fs'
import sharp from 'sharp'

const W = 1200, H = 630
const ICON = 512

const icon = await sharp('public/favicon.svg', { density: 96 * (ICON / 64) })
  .resize(ICON, ICON)
  .png()
  .toBuffer()

await sharp({
  create: { width: W, height: H, channels: 4, background: '#f7f5ee' },
})
  .composite([{ input: icon, left: Math.round((W - ICON) / 2), top: Math.round((H - ICON) / 2) }])
  .png({ compressionLevel: 9 })
  .toFile('public/og.png')
console.log(`wrote public/og.png (${fs.statSync('public/og.png').size} bytes)`)
