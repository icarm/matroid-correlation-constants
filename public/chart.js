// The interactive records explorer. All data — the family curves (single
// source of truth: src/familyData.ts) and this site's verified record
// submissions — arrives as server-injected JSON (#chart-data).
// Progressive enhancement: without JS the server-rendered plot stands.
'use strict'
;(() => {
  const explorer = document.getElementById('records-explorer')
  const fallback = document.getElementById('records-fallback')
  const chart = document.getElementById('atlas-chart')
  if (!explorer || !chart) return

  // ---------------------------------------------------------------------
  // Data: both the family curves and this site's verified record
  // submissions arrive as server-injected JSON (#chart-data). The single
  // source of truth for families is src/familyData.ts.

  let records = []
  let FAMILIES = []
  try {
    const data = JSON.parse(document.getElementById('chart-data').textContent)
    records = data.records
    FAMILIES = data.families
  } catch { /* leave empty */ }
  const allSeries = FAMILIES.flatMap((family) =>
    family.series.map((series) => ({ family, series, key: family.id + ':' + series.id })))

  // ---------------------------------------------------------------------
  // State, synced with the URL so views are shareable.

  const defaults = {
    search: '', field: 'all', rank: 'all', maxN: 100, xAxis: 'size',
    showPoints: true, showExact: true, showLower: true, showBelowOne: false, fullYScale: false,
  }
  const state = { ...defaults, hiddenSeries: new Set() }

  const controls = {
    search: document.getElementById('search-input'),
    field: document.getElementById('field-filter'),
    rank: document.getElementById('rank-filter'),
    maxN: document.getElementById('max-n'),
    maxNOutput: document.getElementById('max-n-output'),
    showPoints: document.getElementById('show-points'),
    showExact: document.getElementById('show-exact'),
    showLower: document.getElementById('show-lower'),
    showBelowOne: document.getElementById('show-below-one'),
    fullYScale: document.getElementById('full-y-scale'),
    xAxis: document.getElementById('toggle-x-axis'),
    reset: document.getElementById('reset-filters'),
    legend: document.getElementById('chart-legend'),
    tooltip: document.getElementById('chart-tooltip'),
    empty: document.getElementById('empty-chart'),
    count: document.getElementById('visible-count'),
    seriesCount: document.getElementById('visible-series-count'),
  }

  const ranks = [...new Set([
    ...allSeries.flatMap(({ series }) => series.points.map((p) => p.rank)),
    ...records.map((r) => r.rank),
  ])].sort((a, b) => a - b)
  for (const r of ranks) {
    const opt = document.createElement('option')
    opt.value = String(r)
    opt.textContent = 'rank ' + r
    controls.rank.append(opt)
  }

  const readUrl = () => {
    const q = new URLSearchParams(location.search)
    if (q.has('q')) state.search = q.get('q')
    if (q.has('field')) state.field = q.get('field')
    if (q.has('rank')) state.rank = q.get('rank')
    if (q.has('maxn')) state.maxN = Math.max(20, Math.min(1000, Number(q.get('maxn')) || 100))
    if (q.get('x') === 'rank') state.xAxis = 'rank'
    for (const [param, key] of [['points', 'showPoints'], ['exact', 'showExact'], ['lower', 'showLower']]) {
      if (q.get(param) === '0') state[key] = false
    }
    if (q.get('below1') === '1') state.showBelowOne = true
    if (q.get('fully') === '1') state.fullYScale = true
    if (q.has('hide')) state.hiddenSeries = new Set(q.get('hide').split(',').filter(Boolean))
  }
  const writeUrl = () => {
    const q = new URLSearchParams()
    if (state.search) q.set('q', state.search)
    if (state.field !== 'all') q.set('field', state.field)
    if (state.rank !== 'all') q.set('rank', state.rank)
    if (state.maxN !== defaults.maxN) q.set('maxn', String(state.maxN))
    if (state.xAxis !== 'size') q.set('x', state.xAxis)
    if (!state.showPoints) q.set('points', '0')
    if (!state.showExact) q.set('exact', '0')
    if (!state.showLower) q.set('lower', '0')
    if (state.showBelowOne) q.set('below1', '1')
    if (state.fullYScale) q.set('fully', '1')
    if (state.hiddenSeries.size) q.set('hide', [...state.hiddenSeries].join(','))
    const qs = q.toString()
    history.replaceState(null, '', qs ? '?' + qs : location.pathname)
  }
  const syncControls = () => {
    controls.search.value = state.search
    controls.field.value = state.field
    controls.rank.value = state.rank
    controls.maxN.value = String(state.maxN)
    controls.maxNOutput.textContent = '≤ ' + state.maxN
    controls.showPoints.checked = state.showPoints
    controls.showExact.checked = state.showExact
    controls.showLower.checked = state.showLower
    controls.showBelowOne.checked = state.showBelowOne
    controls.fullYScale.checked = state.fullYScale
    controls.xAxis.setAttribute('aria-pressed', String(state.xAxis === 'rank'))
    controls.xAxis.textContent = state.xAxis === 'rank' ? 'x-axis: rank' : 'x-axis: |E|'
  }

  // ---------------------------------------------------------------------
  // Filtering.

  const searchIncludes = (values) => {
    const needle = state.search.trim().toLowerCase()
    if (!needle) return true
    return values.some((v) => String(v).toLowerCase().includes(needle))
  }
  const recordMatches = (r) => {
    if (r.n > state.maxN) return false
    if (!state.showBelowOne && r.value < 1) return false
    if (state.rank !== 'all' && r.rank !== Number(state.rank)) return false
    if (state.field !== 'all' && String(r.field) !== state.field && String(r.certField) !== state.field) return false
    return searchIncludes(['matroid #' + r.id, 'GF(' + r.field + ')', 'n = ' + r.n, r.label, ...(r.titles || [])])
  }
  const pointMatches = (family, series, point, broadMatch) => {
    if (point.n > state.maxN) return false
    if (!state.showBelowOne && point.exact.value < 1) return false
    if (state.rank !== 'all' && point.rank !== Number(state.rank)) return false
    if (state.field !== 'all') {
      const wanted = Number(state.field)
      if (point.field !== null && point.field !== undefined) {
        if (point.field !== wanted) return false
      } else if (!family.fields.includes(wanted)) return false
    }
    return broadMatch || searchIncludes([point.parameter])
  }
  const getChartData = () => {
    const concrete = state.showPoints ? records.filter(recordMatches) : []
    const eligible = []
    for (const entry of allSeries) {
      const { family, series } = entry
      if (family.claim === 'exact' && !state.showExact) continue
      if (family.claim === 'lower' && !state.showLower) continue
      const broadMatch = searchIncludes([family.name, family.short, series.label])
      const points = series.points.filter((p) => pointMatches(family, series, p, broadMatch))
      if (points.length) eligible.push({ ...entry, points })
    }
    const rendered = eligible.filter((e) => !state.hiddenSeries.has(e.key))
    return { concrete, eligible, rendered }
  }

  // ---------------------------------------------------------------------
  // Rendering.

  const SVG = 'http://www.w3.org/2000/svg'
  const el = (tag, attrs = {}, text = '') => {
    const node = document.createElementNS(SVG, tag)
    for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, String(v))
    if (text) node.textContent = text
    return node
  }
  const fmt = (v, digits = 3) => Number(v).toFixed(digits).replace(/0+$/, '').replace(/\.$/, '')

  const showTooltip = (event, title, lines) => {
    const t = controls.tooltip
    t.innerHTML = ''
    const strong = document.createElement('strong')
    strong.textContent = title
    t.append(strong)
    for (const line of lines) {
      const div = document.createElement('div')
      div.textContent = line
      t.append(div)
    }
    t.hidden = false
    const pad = 14
    const w = t.offsetWidth
    const x = Math.min(event.clientX + pad, window.innerWidth - w - 8)
    const y = Math.max(8, event.clientY - t.offsetHeight - pad)
    t.style.left = x + 'px'
    t.style.top = y + 'px'
  }
  const hideTooltip = () => { controls.tooltip.hidden = true }
  const hoverable = (node, title, lines, href) => {
    node.addEventListener('pointermove', (e) => showTooltip(e, title, lines))
    node.addEventListener('pointerleave', hideTooltip)
    node.addEventListener('focus', () => {
      const rect = node.getBoundingClientRect()
      showTooltip({ clientX: rect.right, clientY: rect.top }, title, lines)
    })
    node.addEventListener('blur', hideTooltip)
    if (href) {
      node.style.cursor = 'pointer'
      node.addEventListener('click', () => { location.href = href })
      node.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); location.href = href }
      })
    }
  }

  const renderLegend = (eligible) => {
    controls.legend.innerHTML = ''
    for (const { family, series, key } of eligible) {
      const chip = document.createElement('button')
      chip.type = 'button'
      chip.className = 'legend-chip' + (state.hiddenSeries.has(key) ? ' off' : '')
      chip.setAttribute('aria-pressed', String(!state.hiddenSeries.has(key)))
      const swatch = document.createElement('span')
      swatch.className = 'legend-swatch' + (family.claim === 'lower' ? ' dashed' : '')
      swatch.style.setProperty('--swatch', family.color)
      // A single-curve family has one unlabeled series: its chip is just
      // the family's short name.
      chip.append(swatch, document.createTextNode(
        family.short + (series.label ? ' · ' + series.label : '')))
      chip.addEventListener('click', () => {
        if (state.hiddenSeries.has(key)) state.hiddenSeries.delete(key)
        else state.hiddenSeries.add(key)
        update()
      })
      controls.legend.append(chip)
    }
  }

  const render = () => {
    const { concrete, eligible, rendered } = getChartData()
    const W = 980, H = 520
    const M = { top: 28, right: 28, bottom: 62, left: 76 }
    const innerW = W - M.left - M.right
    const innerH = H - M.top - M.bottom
    const yMin = state.showBelowOne ? 0.8 : 1
    const shown = [
      ...concrete.map((r) => r.value),
      ...rendered.flatMap(({ points }) => points.map((p) => p.exact.value)),
    ]
    const observedMax = shown.length ? Math.max(...shown) : 4 / 3
    const yMax = state.fullYScale ? 2 : Math.max(1.36, observedMax + 0.025)
    const xVal = (entry) => (state.xAxis === 'rank' ? entry.rank : entry.n)
    const eligibleX = [...concrete.map(xVal), ...eligible.flatMap(({ points }) => points.map(xVal))]
    const xMax = state.xAxis === 'rank'
      ? Math.max(5, Math.ceil((eligibleX.length ? Math.max(...eligibleX) : 1) / 5) * 5)
      : state.maxN
    const X = (v) => M.left + (v / xMax) * innerW
    const Y = (v) => M.top + ((yMax - v) / (yMax - yMin)) * innerH

    chart.innerHTML = ''
    chart.setAttribute('aria-label', 'Correlation constants against ' +
      (state.xAxis === 'rank' ? 'matroid rank' : 'ground-set size'))
    const grid = el('g', { 'aria-hidden': 'true' })
    for (let i = 0; i <= 6; i++) {
      const v = Math.round((xMax * i) / 6)
      grid.append(el('line', { x1: X(v), y1: M.top, x2: X(v), y2: H - M.bottom, class: 'grid-line' }))
      grid.append(el('text', { x: X(v), y: H - M.bottom + 24, class: 'tick-label', 'text-anchor': 'middle' }, String(v)))
    }
    const yTicks = state.fullYScale ? 5 : 6
    for (let i = 0; i <= yTicks; i++) {
      const v = yMin + ((yMax - yMin) * i) / yTicks
      grid.append(el('line', { x1: M.left, y1: Y(v), x2: W - M.right, y2: Y(v), class: 'grid-line' }))
      grid.append(el('text', { x: M.left - 12, y: Y(v) + 4, class: 'tick-label', 'text-anchor': 'end' }, fmt(v)))
    }
    const target = 4 / 3
    if (target >= yMin && target <= yMax) {
      grid.append(el('line', { x1: M.left, y1: Y(target), x2: W - M.right, y2: Y(target), class: 'grid-line target' }))
      grid.append(el('text', { x: W - M.right - 4, y: Y(target) - 7, class: 'target-label', 'text-anchor': 'end' },
        '4/3 · record to beat (limit)'))
    }
    grid.append(el('line', { x1: M.left, y1: H - M.bottom, x2: W - M.right, y2: H - M.bottom, class: 'axis-line' }))
    grid.append(el('line', { x1: M.left, y1: M.top, x2: M.left, y2: H - M.bottom, class: 'axis-line' }))
    grid.append(el('text', { x: M.left + innerW / 2, y: H - 14, class: 'axis-label', 'text-anchor': 'middle' },
      state.xAxis === 'rank' ? 'Matroid rank' : 'Ground-set size |E|'))
    const yLabel = el('text', { x: 20, y: M.top + innerH / 2, class: 'axis-label', 'text-anchor': 'middle' }, 'correlation constant')
    yLabel.setAttribute('transform', `rotate(-90 20 ${M.top + innerH / 2})`)
    grid.append(yLabel)
    chart.append(grid)

    const defs = el('defs')
    const clip = el('clipPath', { id: 'plot-clip' })
    clip.append(el('rect', { x: M.left, y: M.top, width: innerW, height: innerH }))
    defs.append(clip)
    chart.append(defs)
    const marks = el('g', { 'clip-path': 'url(#plot-clip)' })

    rendered.forEach(({ family, series, points }, index) => {
      const sorted = [...points].sort((a, b) => xVal(a) - xVal(b) || a.n - b.n)
      const path = sorted.map((p, i) =>
        (i === 0 ? 'M' : 'L') + X(xVal(p)).toFixed(2) + ',' + Y(p.exact.value).toFixed(2)).join(' ')
      const opacity = Math.max(0.55, 1 - index * 0.05)
      if (sorted.length > 1) {
        const curve = el('path', {
          d: path,
          class: 'curve-path' + (family.claim === 'lower' ? ' lower-bound' : ''),
          stroke: family.color, opacity,
        })
        curve.style.cursor = 'pointer'
        curve.style.pointerEvents = 'stroke'
        curve.addEventListener('click', () => { location.href = '/family/' + family.id })
        marks.append(curve)
      }
      for (const p of sorted) {
        const dot = el('circle', {
          cx: X(xVal(p)), cy: Y(p.exact.value), r: 4, class: 'curve-point',
          fill: family.color, opacity, tabindex: 0, role: 'img',
          'aria-label': `${family.short}, ${p.parameter}, value ${p.exact.label}`,
        })
        hoverable(dot, family.short, [
          (series.label ? series.label + ' · ' : '') + p.parameter,
          'value ' + p.exact.label + ' ≈ ' + fmt(p.exact.value, 5),
          '|E| = ' + p.n + ' · rank ' + p.rank,
          family.claim === 'exact' ? 'proved exact' : 'certified lower bound',
        ], '/family/' + family.id)
        marks.append(dot)
      }
    })

    for (const r of concrete) {
      const dot = el('circle', {
        cx: X(xVal(r)), cy: Y(r.value), r: 6.5,
        class: 'matroid-point',
        tabindex: 0, role: 'link',
        'aria-label': `matroid #${r.id}, value ${r.label}`,
      })
      // No separate field line: the titles say it ("GF(3) record"), and a
      // club member's representation details live on its matroid page.
      hoverable(dot, 'matroid #' + r.id, [
        (r.titles || []).join(' · '),
        'α = ' + r.label + ' ≈ ' + fmt(r.value, 5),
        '|E| = ' + r.n + ' · rank ' + r.rank + ' · ' + Number(r.bases).toLocaleString() + ' bases',
      ], '/matroid/' + r.id)
      marks.append(dot)
    }
    chart.append(marks)

    controls.empty.hidden = concrete.length + rendered.length !== 0
    controls.count.textContent = concrete.length + (concrete.length === 1 ? ' record point' : ' record points')
    controls.seriesCount.textContent = rendered.length + ' curve series'
    renderLegend(eligible)
  }

  const update = () => {
    syncControls()
    writeUrl()
    render()
  }

  // ---------------------------------------------------------------------
  // Wiring.

  controls.search.addEventListener('input', () => { state.search = controls.search.value; update() })
  controls.field.addEventListener('change', () => { state.field = controls.field.value; update() })
  controls.rank.addEventListener('change', () => { state.rank = controls.rank.value; update() })
  controls.maxN.addEventListener('input', () => { state.maxN = Number(controls.maxN.value); update() })
  for (const key of ['showPoints', 'showExact', 'showLower', 'showBelowOne', 'fullYScale']) {
    controls[key].addEventListener('change', () => { state[key] = controls[key].checked; update() })
  }
  controls.xAxis.addEventListener('click', () => {
    state.xAxis = state.xAxis === 'rank' ? 'size' : 'rank'
    update()
  })
  controls.reset.addEventListener('click', () => {
    Object.assign(state, defaults)
    state.hiddenSeries = new Set()
    update()
  })

  // The tooltip is position:fixed; hoist it to <body> so no ancestor's
  // transform or overflow can interfere with viewport positioning.
  document.body.append(controls.tooltip)

  readUrl()
  if (fallback) fallback.hidden = true
  explorer.hidden = false
  update()
})()
