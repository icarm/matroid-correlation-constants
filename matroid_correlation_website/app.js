import {
  challenges,
  families,
  matroids,
  siteConfig,
} from "./catalog.js";

const SVG_NS = "http://www.w3.org/2000/svg";
const chart = document.querySelector("#atlas-chart");
const tooltip = document.querySelector("#chart-tooltip");
const emptyChart = document.querySelector("#empty-chart");
const legend = document.querySelector("#chart-legend");
const recordsBody = document.querySelector("#records-body");
const familyGrid = document.querySelector("#family-grid");
const challengeGrid = document.querySelector("#challenge-grid");
const detailDialog = document.querySelector("#detail-dialog");
const detailContent = document.querySelector("#detail-content");
const toast = document.querySelector("#toast");
const xAxisToggle = document.querySelector("#toggle-x-axis");
const xAxisToggleLabel = document.querySelector("#x-axis-toggle-label");

const controls = {
  search: document.querySelector("#search-input"),
  field: document.querySelector("#field-filter"),
  rank: document.querySelector("#rank-filter"),
  maxN: document.querySelector("#max-n"),
  maxNOutput: document.querySelector("#max-n-output"),
  showPoints: document.querySelector("#show-points"),
  showExact: document.querySelector("#show-exact"),
  showLower: document.querySelector("#show-lower"),
  showBelowOne: document.querySelector("#show-below-one"),
  fullYScale: document.querySelector("#full-y-scale"),
};

const defaults = {
  search: "",
  field: "all",
  rank: "all",
  maxN: 300,
  xAxis: "size",
  showPoints: true,
  showExact: true,
  showLower: true,
  showBelowOne: false,
  fullYScale: false,
};

const state = {
  ...defaults,
  hiddenSeries: new Set(),
};

let initialRender = true;

const statusLabels = {
  "computationally-checked": "computed exactly",
  "literature-verified": "literature + check",
  "proof-reviewed": "proof reviewed",
};

const claimLabels = {
  exact: "exact curve",
  "lower-bound": "certified lower bound",
};

const escapeHtml = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

const proseMarkup = (value) => escapeHtml(value);

const texInline = (value) =>
  `<span class="tex-inline">\\(${escapeHtml(value)}\\)</span>`;

const alphaBarMarkup = texInline("\\overline{\\alpha}");

const parameterMarkup = (value) => {
  const simple = String(value).match(/^([pqr])\s*=\s*(\d+)$/);
  if (simple) return texInline(simple[1] + "=" + simple[2]);
  const rank = String(value).match(/^rank\((A|PG)\)\s*=\s*(\d+)$/);
  if (rank) return texInline("\\operatorname{rk}(" + rank[1] + ")=" + rank[2]);
  const system = String(value).match(/^S\((\d+),(\d+),n\)$/);
  if (system) return texInline("S(" + system[1] + "," + system[2] + ",n)");
  return proseMarkup(value);
};

const clearMath = (element) => {
  if (element && window.MathJax?.typesetClear) {
    window.MathJax.typesetClear([element]);
  }
};

let typesetQueue = window.mathJaxReady || Promise.resolve();

const typesetMath = (elements) => {
  typesetQueue = typesetQueue
    .then(() => {
      if (!window.MathJax?.typesetPromise) return undefined;
      return window.MathJax.typesetPromise(elements);
    })
    .catch((error) => {
      console.error("MathJax typesetting failed:", error);
    });
  return typesetQueue;
};

let documentTypesetPromise = null;

const typesetDocument = () => {
  if (documentTypesetPromise) return documentTypesetPromise;
  documentTypesetPromise = typesetMath([document.body]).then(() => {
    document.documentElement.dataset.mathReady = "true";
  });
  return documentTypesetPromise;
};

const createSvg = (tag, attributes = {}, text = "") => {
  const node = document.createElementNS(SVG_NS, tag);
  Object.entries(attributes).forEach(([key, value]) => {
    if (value !== null && value !== undefined) {
      node.setAttribute(key, String(value));
    }
  });
  if (text) node.textContent = text;
  return node;
};

const formatDecimal = (value, digits = 4) =>
  Number(value)
    .toFixed(digits)
    .replace(/0+$/, "")
    .replace(/\.$/, "");

const formatFields = (fields) => {
  if (!fields?.length) return '<span class="verification-badge">not specified</span>';
  return fields
    .map(
      (field) =>
        `<span class="field-badge">${texInline(
          "\\operatorname{GF}(" + Number(field) + ")",
        )}</span>`,
    )
    .join("");
};

const formatCharacteristics = (characteristics) =>
  (characteristics || [])
    .map(
      (prime) =>
        `<span class="characteristic-badge">${texInline(
          "\\operatorname{char}=" + Number(prime),
        )}</span>`,
    )
    .join("");

const showToast = (message) => {
  toast.textContent = message;
  toast.classList.add("visible");
  window.clearTimeout(showToast.timeout);
  showToast.timeout = window.setTimeout(() => toast.classList.remove("visible"), 2400);
};

const allSeries = () =>
  families.flatMap((family) =>
    family.series.map((series, seriesIndex) => ({
      family,
      series,
      seriesIndex,
      key: family.id + ":" + series.id,
    })),
  );

const humanList = (values) => {
  if (values.length <= 1) return values[0] || "";
  if (values.length === 2) return values.join(" and ");
  return values.slice(0, -1).join(", ") + ", and " + values.at(-1);
};

const getScoreCandidates = () => {
  const catalogCandidates = matroids.map((matroid) => ({
    key: "matroid:" + matroid.id,
    kind: "matroid",
    attainment: "on the nose",
    claimType: "exact",
    score: matroid.exact,
    name: matroid.name,
    matroid,
  }));

  const familyCandidates = families.flatMap((family) => {
    const finiteMembers = family.series.flatMap((series) =>
      series.points.map((point) => ({
        key: "family-point:" + family.id + ":" + series.id + ":" + point.parameter,
        kind: "family-point",
        attainment: "on the nose",
        claimType: family.claimType,
        score: point.exact,
        name: family.name,
        family,
        series,
        point,
      })),
    );
    const familyBenchmark = {
      key: "family-limit:" + family.id,
      kind: family.supremumKind === "attained" ? "family-value" : "family-limit",
      attainment:
        family.supremumKind === "attained" ? "on the nose" : "in the limit",
      claimType: family.claimType,
      score: family.supremum,
      name: family.name,
      family,
    };
    return [...finiteMembers, familyBenchmark];
  });

  return [...catalogCandidates, ...familyCandidates];
};

let featuredBenchmark = null;

const setInitialMetrics = () => {
  const candidates = getScoreCandidates();
  const maximum = Math.max(...candidates.map((candidate) => candidate.score.value));
  const leaders = candidates.filter(
    (candidate) => Math.abs(candidate.score.value - maximum) < 1e-12,
  );
  const leaderNames = [
    ...new Set(
      leaders.map((leader) =>
        leader.family ? leader.family.shortName : leader.matroid.shortName,
      ),
    ),
  ];
  const attainments = new Set(leaders.map((leader) => leader.attainment));
  const attainmentLabel =
    attainments.size > 1 ? "finite + limit" : [...attainments][0];
  const allLimits = leaders.every((leader) => leader.kind === "family-limit");
  const allLowerBounds = leaders.every(
    (leader) => leader.claimType === "lower-bound",
  );

  featuredBenchmark = {
    score: leaders[0].score,
    leaders,
    leaderNames,
    attainmentLabel,
    allLimits,
    allLowerBounds,
  };

  const heroFraction = document.querySelector("#hero-record-fraction");
  const metricBenchmark = document.querySelector("#metric-benchmark");
  clearMath(heroFraction);
  clearMath(metricBenchmark);
  heroFraction.innerHTML = texInline(featuredBenchmark.score.tex);
  document.querySelector("#hero-record-name").textContent =
    leaderNames.length >= 4
      ? "Uniform, affine, projective, and Steiner-system families"
      : humanList(leaderNames);
  document.querySelector("#hero-record-status").textContent = attainmentLabel;
  document.querySelector("#hero-record-kind").textContent = allLowerBounds
    ? "certified family benchmark"
    : "current verified benchmark";
  document.querySelector("#hero-record-action").childNodes[0].textContent =
    "Inspect the benchmark ";
  document.querySelector("#metric-matroids").textContent = String(matroids.length);
  document.querySelector("#metric-families").textContent = String(families.length);
  document.querySelector("#metric-curves").textContent = String(allSeries().length);
  metricBenchmark.innerHTML = texInline(featuredBenchmark.score.tex);
  document.querySelector("#data-version").textContent = siteConfig.dataVersion;
  if (!initialRender) typesetMath([heroFraction, metricBenchmark]);
};

const populateRanks = () => {
  const ranks = new Set(matroids.map((matroid) => matroid.rank));
  allSeries().forEach(({ series }) => {
    series.points.forEach((point) => ranks.add(point.rank));
  });
  [...ranks]
    .sort((a, b) => a - b)
    .forEach((rank) => {
      const option = document.createElement("option");
      option.value = String(rank);
      option.textContent = "Rank " + rank;
      controls.rank.append(option);
    });
};

const readUrlState = () => {
  const params = new URLSearchParams(window.location.search);
  const field = params.get("field");
  const rank = params.get("rank");
  const maxN = Number(params.get("maxN"));

  if ([...controls.field.options].some((option) => option.value === field)) {
    state.field = field;
  }
  if ([...controls.rank.options].some((option) => option.value === rank)) {
    state.rank = rank;
  }
  if (params.has("maxN") && Number.isFinite(maxN)) {
    state.maxN = Math.max(20, Math.min(1000, maxN));
  }
  state.xAxis = params.get("x") === "rank" ? "rank" : "size";

  state.search = params.get("q") || "";
  state.showPoints = params.get("points") !== "0";
  state.showExact = params.get("exact") !== "0";
  state.showLower = params.get("lower") !== "0";
  state.showBelowOne = params.get("below") === "1";
  state.fullYScale = params.get("full") === "1";

  const hidden = params.get("hidden");
  if (hidden) {
    hidden
      .split(",")
      .filter((key) => allSeries().some((entry) => entry.key === key))
      .forEach((key) => state.hiddenSeries.add(key));
  }
};

const writeStateToControls = () => {
  controls.search.value = state.search;
  controls.field.value = state.field;
  controls.rank.value = state.rank;
  controls.maxN.value = String(state.maxN);
  controls.maxNOutput.value = "≤ " + state.maxN;
  controls.maxNOutput.textContent = "≤ " + state.maxN;
  controls.showPoints.checked = state.showPoints;
  controls.showExact.checked = state.showExact;
  controls.showLower.checked = state.showLower;
  controls.showBelowOne.checked = state.showBelowOne;
  controls.fullYScale.checked = state.fullYScale;
  const rankAxis = state.xAxis === "rank";
  xAxisToggle.setAttribute("aria-pressed", String(rankAxis));
  xAxisToggle.title = rankAxis
    ? "Switch the horizontal axis to ground-set size"
    : "Switch the horizontal axis to rank";
  xAxisToggleLabel.textContent = rankAxis
    ? "X-axis: rank"
    : "X-axis: ground-set size";
};

const updateUrl = (detail = null) => {
  const params = new URLSearchParams();
  if (state.search) params.set("q", state.search);
  if (state.field !== defaults.field) params.set("field", state.field);
  if (state.rank !== defaults.rank) params.set("rank", state.rank);
  if (state.maxN !== defaults.maxN) params.set("maxN", String(state.maxN));
  if (state.xAxis !== defaults.xAxis) params.set("x", state.xAxis);
  if (!state.showPoints) params.set("points", "0");
  if (!state.showExact) params.set("exact", "0");
  if (!state.showLower) params.set("lower", "0");
  if (state.showBelowOne) params.set("below", "1");
  if (state.fullYScale) params.set("full", "1");
  if (state.hiddenSeries.size) {
    params.set("hidden", [...state.hiddenSeries].sort().join(","));
  }
  if (detail) params.set("detail", detail);

  const query = params.toString();
  const nextUrl =
    window.location.pathname + (query ? "?" + query : "") + window.location.hash;
  window.history.replaceState({}, "", nextUrl);
};

const syncStateFromControls = () => {
  state.search = controls.search.value.trim();
  state.field = controls.field.value;
  state.rank = controls.rank.value;
  state.maxN = Number(controls.maxN.value);
  state.showPoints = controls.showPoints.checked;
  state.showExact = controls.showExact.checked;
  state.showLower = controls.showLower.checked;
  state.showBelowOne = controls.showBelowOne.checked;
  state.fullYScale = controls.fullYScale.checked;
  controls.maxNOutput.value = "≤ " + state.maxN;
  controls.maxNOutput.textContent = "≤ " + state.maxN;
};

const searchIncludes = (values) => {
  if (!state.search) return true;
  const haystack = values.filter(Boolean).join(" ").toLocaleLowerCase();
  return haystack.includes(state.search.toLocaleLowerCase());
};

const matroidMatches = (matroid) => {
  if (matroid.n > state.maxN) return false;
  if (!state.showBelowOne && matroid.exact.value < 1) return false;
  if (state.field !== "all" && !matroid.fields.includes(Number(state.field))) {
    return false;
  }
  if (state.rank !== "all" && matroid.rank !== Number(state.rank)) return false;
  return searchIncludes([
    matroid.name,
    matroid.shortName,
    matroid.construction,
    matroid.summary,
    matroid.provenance,
    matroid.discoveryDate,
    matroid.aiDisclosure,
    ...(matroid.contributors || []),
  ]);
};

const seriesSearchMatches = (family, series) =>
  searchIncludes([
    family.name,
    family.shortName,
    family.summary,
    family.displayedFormula,
    family.parameter,
    family.representationStatement,
    family.discoveryDate,
    family.aiDisclosure,
    series.label,
    ...(family.contributors || []),
  ]);

const pointMatches = (family, series, point, broadSearchMatch) => {
  if (point.n > state.maxN) return false;
  if (!state.showBelowOne && point.exact.value < 1) return false;
  if (state.rank !== "all" && point.rank !== Number(state.rank)) return false;

  if (state.field !== "all") {
    const requestedField = Number(state.field);
    const explicitField = point.field ?? series.field;
    if (explicitField !== null && explicitField !== undefined) {
      if (explicitField !== requestedField) return false;
    } else if (!family.fields.includes(requestedField)) {
      return false;
    }
  }

  if (!broadSearchMatch && !searchIncludes([point.parameter])) return false;
  return true;
};

const getChartData = () => {
  const concrete = state.showPoints ? matroids.filter(matroidMatches) : [];
  const eligibleSeries = [];

  allSeries().forEach((entry) => {
    const { family, series } = entry;
    if (family.claimType === "exact" && !state.showExact) return;
    if (family.claimType === "lower-bound" && !state.showLower) return;
    const broadSearchMatch = seriesSearchMatches(family, series);
    const points = series.points.filter((point) =>
      pointMatches(family, series, point, broadSearchMatch),
    );
    if (points.length) eligibleSeries.push({ ...entry, points });
  });

  const renderedSeries = eligibleSeries.filter(
    (entry) => !state.hiddenSeries.has(entry.key),
  );
  return { concrete, eligibleSeries, renderedSeries };
};

const appendText = (parent, text, x, y, className, attributes = {}) => {
  parent.append(
    createSvg(
      "text",
      {
        x,
        y,
        class: className,
        ...attributes,
      },
      text,
    ),
  );
};

const tooltipPosition = (event) => {
  const estimatedWidth = 270;
  const left = Math.min(event.clientX, window.innerWidth - estimatedWidth);
  const top = Math.max(42, Math.min(event.clientY, window.innerHeight - 42));
  tooltip.style.left = Math.max(8, left) + "px";
  tooltip.style.top = top + "px";
};

const showPointTooltip = (event, title, lines) => {
  tooltip.innerHTML =
    "<strong>" +
    escapeHtml(title) +
    "</strong>" +
    lines.map((line) => "<span>" + escapeHtml(line) + "</span>").join("");
  tooltipPosition(event);
  tooltip.classList.add("visible");
};

const hideTooltip = () => tooltip.classList.remove("visible");

const renderLegend = (eligibleSeries) => {
  legend.innerHTML = "";
  if (!eligibleSeries.length) {
    legend.innerHTML = '<span class="verification-badge">No curve series in view</span>';
    return;
  }

  eligibleSeries.forEach(({ family, series, seriesIndex, key }) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className =
      "legend-item" + (state.hiddenSeries.has(key) ? " hidden-series" : "");
    button.setAttribute(
      "aria-pressed",
      state.hiddenSeries.has(key) ? "false" : "true",
    );
    const opacity = Math.max(0.55, 1 - seriesIndex * 0.11);
    button.innerHTML =
      `<span class="legend-swatch ${family.claimType === "lower-bound" ? "lower-bound" : ""}" style="--swatch:${escapeHtml(family.color)};opacity:${opacity}"></span>` +
      `<span>${escapeHtml(family.shortName)} · ${escapeHtml(series.label)}</span>`;
    button.addEventListener("click", () => {
      if (state.hiddenSeries.has(key)) state.hiddenSeries.delete(key);
      else state.hiddenSeries.add(key);
      updateUrl();
      render();
    });
    legend.append(button);
  });
};

const renderChart = () => {
  const { concrete, eligibleSeries, renderedSeries } = getChartData();
  const width = 980;
  const height = 520;
  const margin = { top: 28, right: 28, bottom: 62, left: 76 };
  const innerWidth = width - margin.left - margin.right;
  const innerHeight = height - margin.top - margin.bottom;
  const yMin = state.showBelowOne ? 0.8 : 1;
  const displayedValues = [
    ...concrete.map((matroid) => matroid.exact.value),
    ...renderedSeries.flatMap(({ points }) => points.map((point) => point.exact.value)),
  ];
  const observedMax = displayedValues.length ? Math.max(...displayedValues) : 4 / 3;
  const yMax = state.fullYScale ? 2 : Math.max(1.36, observedMax + 0.025);
  const xMin = 0;
  const xValue = (entry) => (state.xAxis === "rank" ? entry.rank : entry.n);
  const eligibleXValues = [
    ...concrete.map(xValue),
    ...eligibleSeries.flatMap(({ points }) => points.map(xValue)),
  ];
  const largestEligibleRank = eligibleXValues.length
    ? Math.max(...eligibleXValues)
    : 1;
  const xMax =
    state.xAxis === "rank"
      ? Math.max(5, Math.ceil(largestEligibleRank / 5) * 5)
      : state.maxN;
  const xAxisLabel =
    state.xAxis === "rank" ? "Matroid rank" : "Ground-set size |E|";
  const xAxisProse =
    state.xAxis === "rank" ? "matroid rank" : "ground-set size";

  const xScale = (value) =>
    margin.left + ((value - xMin) / (xMax - xMin)) * innerWidth;
  const yScale = (value) =>
    margin.top + ((yMax - value) / (yMax - yMin)) * innerHeight;

  chart.innerHTML = "";
  const title = createSvg("title", {}, "Matroid correlation constants");
  const description = createSvg(
    "desc",
    {},
    "Individually cataloged matroids and parameterized family values plotted against " +
      xAxisProse +
      ".",
  );
  chart.setAttribute(
    "aria-label",
    "Plot of correlation ratio against " + xAxisProse,
  );
  chart.append(title, description);

  const defs = createSvg("defs");
  const clipPath = createSvg("clipPath", { id: "plot-clip" });
  clipPath.append(
    createSvg("rect", {
      x: margin.left,
      y: margin.top,
      width: innerWidth,
      height: innerHeight,
    }),
  );
  defs.append(clipPath);
  chart.append(defs);

  const grid = createSvg("g", { "aria-hidden": "true" });
  const xTicks = 6;
  for (let index = 0; index <= xTicks; index += 1) {
    const value = Math.round((xMax * index) / xTicks);
    const x = xScale(value);
    grid.append(
      createSvg("line", {
        x1: x,
        y1: margin.top,
        x2: x,
        y2: height - margin.bottom,
        class: "grid-line",
      }),
    );
    appendText(grid, String(value), x, height - margin.bottom + 24, "tick-label", {
      "text-anchor": "middle",
    });
  }

  const yTicks = state.fullYScale ? 5 : 6;
  for (let index = 0; index <= yTicks; index += 1) {
    const value = yMin + ((yMax - yMin) * index) / yTicks;
    const y = yScale(value);
    grid.append(
      createSvg("line", {
        x1: margin.left,
        y1: y,
        x2: width - margin.right,
        y2: y,
        class: "grid-line",
      }),
    );
    appendText(grid, formatDecimal(value, 3), margin.left - 12, y + 4, "tick-label", {
      "text-anchor": "end",
    });
  }

  const target = 4 / 3;
  if (target >= yMin && target <= yMax) {
    const targetY = yScale(target);
    grid.append(
      createSvg("line", {
        x1: margin.left,
        y1: targetY,
        x2: width - margin.right,
        y2: targetY,
        class: "grid-line target",
      }),
    );
    appendText(
      grid,
      "4/3 · record to beat (limit)",
      width - margin.right - 4,
      targetY - 7,
      "target-label",
      { "text-anchor": "end" },
    );
  }

  grid.append(
    createSvg("line", {
      x1: margin.left,
      y1: height - margin.bottom,
      x2: width - margin.right,
      y2: height - margin.bottom,
      class: "axis-line",
    }),
    createSvg("line", {
      x1: margin.left,
      y1: margin.top,
      x2: margin.left,
      y2: height - margin.bottom,
      class: "axis-line",
    }),
  );
  appendText(
    grid,
    xAxisLabel,
    margin.left + innerWidth / 2,
    height - 14,
    "axis-label",
    { "text-anchor": "middle" },
  );
  appendText(
    grid,
    "correlation ratio",
    20,
    margin.top + innerHeight / 2,
    "axis-label",
    {
      "text-anchor": "middle",
      transform: `rotate(-90 20 ${margin.top + innerHeight / 2})`,
    },
  );
  chart.append(grid);

  const marks = createSvg("g", { "clip-path": "url(#plot-clip)" });
  renderedSeries.forEach(({ family, series, seriesIndex, points }) => {
    const sorted = [...points].sort(
      (a, b) => xValue(a) - xValue(b) || a.n - b.n,
    );
    const pathData = sorted
      .map(
        (point, index) =>
          (index === 0 ? "M" : "L") +
          xScale(xValue(point)).toFixed(2) +
          "," +
          yScale(point.exact.value).toFixed(2),
      )
      .join(" ");
    const opacity = Math.max(0.55, 1 - seriesIndex * 0.11);

    if (sorted.length > 1) {
      marks.append(
        createSvg("path", {
          d: pathData,
          class:
            "curve-path" +
            (family.claimType === "lower-bound" ? " lower-bound" : ""),
          stroke: family.color,
          opacity,
        }),
      );
      const hit = createSvg("path", {
        d: pathData,
        class: "curve-hit",
        tabindex: "0",
        role: "button",
        "aria-label": "Open " + family.name + ", " + series.label,
      });
      hit.addEventListener("click", () => openFamily(family.id, series.id));
      hit.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          openFamily(family.id, series.id);
        }
      });
      marks.append(hit);
    }

    sorted.forEach((point) => {
      const circle = createSvg("circle", {
        cx: xScale(xValue(point)),
        cy: yScale(point.exact.value),
        r: 5,
        class: "curve-point",
        fill: family.color,
        opacity,
        tabindex: "0",
        role: "button",
        "aria-label":
          family.shortName +
          ", " +
          point.parameter +
          ", value " +
          point.exact.label,
      });
      const tooltipLines = [
        series.label + " · " + point.parameter,
        "value " +
          point.exact.label +
          " ≈ " +
          formatDecimal(point.exact.value, 5),
        "|E| = " + point.n + " · rank " + point.rank,
        family.claimType === "exact" ? "proved exact" : "certified lower bound",
      ];
      circle.addEventListener("pointermove", (event) =>
        showPointTooltip(event, family.shortName, tooltipLines),
      );
      circle.addEventListener("pointerleave", hideTooltip);
      circle.addEventListener("focus", (event) => {
        const rect = event.target.getBoundingClientRect();
        showPointTooltip(
          { clientX: rect.left + rect.width, clientY: rect.top + rect.height / 2 },
          family.shortName,
          tooltipLines,
        );
      });
      circle.addEventListener("blur", hideTooltip);
      circle.addEventListener("click", () =>
        openFamily(family.id, series.id, point),
      );
      circle.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          openFamily(family.id, series.id, point);
        }
      });
      marks.append(circle);
    });
  });

  concrete.forEach((matroid) => {
    const circle = createSvg("circle", {
      cx: xScale(xValue(matroid)),
      cy: yScale(matroid.exact.value),
      r: matroid.recordClass === "global" ? 8 : 7,
      class:
        "matroid-point" +
        (matroid.recordClass === "global" ? " global-record" : ""),
      tabindex: "0",
      role: "button",
      "aria-label": matroid.name + ", exact value " + matroid.exact.label,
    });
    const tooltipLines = [
      "exact value = " +
        matroid.exact.label +
        " ≈ " +
        formatDecimal(matroid.exact.value, 5),
      "|E| = " + matroid.n + " · rank " + matroid.rank,
      matroid.fields.length
        ? "verified over " + matroid.fields.map((field) => "GF(" + field + ")").join(", ")
        : "field not specified",
      statusLabels[matroid.verificationStatus] || matroid.verificationStatus,
      "discovery: " + matroid.discoveryDate,
    ];
    circle.addEventListener("pointermove", (event) =>
      showPointTooltip(event, matroid.name, tooltipLines),
    );
    circle.addEventListener("pointerleave", hideTooltip);
    circle.addEventListener("focus", (event) => {
      const rect = event.target.getBoundingClientRect();
      showPointTooltip(
        { clientX: rect.left + rect.width, clientY: rect.top + rect.height / 2 },
        matroid.name,
        tooltipLines,
      );
    });
    circle.addEventListener("blur", hideTooltip);
    circle.addEventListener("click", () => openMatroid(matroid.id));
    circle.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openMatroid(matroid.id);
      }
    });
    marks.append(circle);
  });
  chart.append(marks);

  emptyChart.hidden = concrete.length + renderedSeries.length !== 0;
  document.querySelector("#visible-count").textContent =
    concrete.length + " catalog " + (concrete.length === 1 ? "point" : "points");
  document.querySelector("#visible-series-count").textContent =
    renderedSeries.length +
    " curve " +
    (renderedSeries.length === 1 ? "series" : "series");
  renderLegend(eligibleSeries);
};

const renderRecords = () => {
  const matching = matroids
    .filter(matroidMatches)
    .sort((a, b) => b.exact.value - a.exact.value || a.n - b.n);
  clearMath(recordsBody);
  recordsBody.innerHTML = "";

  if (!matching.length) {
    recordsBody.innerHTML =
      '<tr><td colspan="8"><span class="verification-badge">No catalog entries match these filters</span></td></tr>';
    document.querySelector("#record-table-caption").textContent =
      "No individually cataloged certificates match these filters.";
    return;
  }

  matching.forEach((matroid) => {
    const row = document.createElement("tr");
    row.tabIndex = 0;
    row.setAttribute("role", "button");
    row.setAttribute("aria-label", "Open " + matroid.name);
    row.innerHTML = `
      <td class="record-name-cell">
        <strong>${escapeHtml(matroid.name)}</strong>
        <span>${escapeHtml(matroid.representationType)}</span>
      </td>
      <td class="exact-cell">${texInline(matroid.exact.tex)}</td>
      <td>${matroid.n}</td>
      <td>${matroid.rank}</td>
      <td>${escapeHtml(matroid.discoveryDate)}</td>
      <td><div class="field-badges">${formatFields(matroid.fields)}</div></td>
      <td><span class="verification-badge">${escapeHtml(
        statusLabels[matroid.verificationStatus] || matroid.verificationStatus,
      )}</span></td>
      <td><span class="table-open" aria-hidden="true">→</span></td>
    `;
    row.addEventListener("click", () => openMatroid(matroid.id));
    row.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openMatroid(matroid.id);
      }
    });
    recordsBody.append(row);
  });
  document.querySelector("#record-table-caption").textContent =
    matching.length +
    " individually cataloged exact " +
    (matching.length === 1 ? "certificate" : "certificates") +
    ", sorted by value; finite family members remain on the curves.";
  if (!initialRender) typesetMath([recordsBody]);
};

const renderFamilyCards = () => {
  clearMath(familyGrid);
  familyGrid.innerHTML = "";
  families.forEach((family) => {
    const card = document.createElement("article");
    card.className = "family-card";
    card.tabIndex = 0;
    card.setAttribute("role", "button");
    card.setAttribute("aria-label", "Open " + family.name);
    card.style.setProperty("--family-color", family.color);
    const curveClass = family.claimType === "lower-bound" ? " lower-bound" : "";
    const benchmarkLabel =
      family.claimType === "exact" && family.supremumKind === "attained"
        ? "Exact value"
        : "Curve limit";
    card.innerHTML = `
      <div class="family-card-top">
        <span class="claim-badge ${family.claimType}">${escapeHtml(
          claimLabels[family.claimType],
        )}</span>
        <span class="verification-badge">${family.series.length} ${family.series.length === 1 ? "series" : "series"}</span>
      </div>
      <h3>${escapeHtml(family.name)}</h3>
      <p class="family-byline">${escapeHtml(
        family.contributors.join(" · "),
      )}</p>
      <p class="family-discovery-date">Discovery: ${escapeHtml(
        family.discoveryDate,
      )}</p>
      <p>${proseMarkup(family.summary)}</p>
      <div class="family-formula">${texInline(family.displayedFormula)}</div>
      <div class="family-card-footer">
        <div>
          <span>${benchmarkLabel}</span>
          <strong>${texInline(family.supremum.tex)}</strong>
        </div>
        <svg class="curve-mini${curveClass}" viewBox="0 0 75 34" aria-hidden="true">
          <path d="M2 29 C16 27, 22 19, 34 18 S52 8, 73 5"></path>
        </svg>
      </div>
    `;
    card.addEventListener("click", () => openFamily(family.id));
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openFamily(family.id);
      }
    });
    familyGrid.append(card);
  });
  if (!initialRender) typesetMath([familyGrid]);
};

const renderChallenges = () => {
  clearMath(challengeGrid);
  challengeGrid.innerHTML = "";
  challenges.forEach((challenge) => {
    const card = document.createElement("article");
    card.className = "challenge-card";
    const fieldRecordMarkup = challenge.showFieldRecords
      ? `<div class="challenge-field-records" aria-label="Supported field leaderboards">
          ${siteConfig.supportedFields
            .map(
              (field) =>
                `<span>${texInline("\\operatorname{GF}(" + field + ")")}</span>`,
            )
            .join("")}
        </div>`
      : "";
    card.innerHTML = `
      <p class="eyebrow">${escapeHtml(challenge.eyebrow)}</p>
      <h3>${proseMarkup(challenge.title)}</h3>
      <p>${proseMarkup(challenge.description)}</p>
      ${fieldRecordMarkup}
      <div class="challenge-target">
        <span>Target</span>
        <strong>${texInline(challenge.target)}</strong>
      </div>
    `;
    challengeGrid.append(card);
  });
  if (!initialRender) typesetMath([challengeGrid]);
};

const matrixMarkup = (matrix) => {
  if (!matrix) return "";
  const rows = matrix
    .map(
      (row) =>
        "<tr>" + row.map((entry) => "<td>" + escapeHtml(entry) + "</td>").join("") + "</tr>",
    )
    .join("");
  return `
    <section class="detail-section">
      <span class="detail-section-label">Computer-ready representation</span>
      <h4>Matrix over the verified field</h4>
      <div class="matrix-wrap"><table class="matrix-table"><tbody>${rows}</tbody></table></div>
    </section>
  `;
};

const showDialog = (detailKey) => {
  hideTooltip();
  if (typeof detailDialog.showModal === "function") {
    if (!detailDialog.open) detailDialog.showModal();
  } else {
    detailDialog.setAttribute("open", "");
  }
  updateUrl(detailKey);
};

function openFeaturedBenchmark() {
  if (!featuredBenchmark) return;
  const seen = new Set();
  const representativeLeaders = featuredBenchmark.leaders.filter((leader) => {
    const entityKey = leader.family
      ? "family:" + leader.family.id
      : "matroid:" + leader.matroid.id;
    if (seen.has(entityKey)) return false;
    seen.add(entityKey);
    return true;
  });
  const leaderRows = representativeLeaders
    .map((leader, index) => {
      const entity = leader.family || leader.matroid;
      const evidence = leader.family
        ? (claimLabels[leader.claimType] || leader.claimType) +
          " · " +
          leader.attainment
        : "exact finite certificate · on the nose";
      return `
        <div class="benchmark-entry">
          <div>
            <strong>${escapeHtml(entity.name)}</strong>
            <span>${escapeHtml(evidence)}</span>
          </div>
          <button class="text-button" type="button" data-benchmark-leader="${index}">
            Inspect →
          </button>
        </div>
      `;
    })
    .join("");
  const attainmentCopy = featuredBenchmark.allLimits
    ? "The score is approached in the limit. None of the displayed finite parameter values equals it."
    : "At least one accepted finite construction attains this score on the nose.";
  const evidenceCopy = featuredBenchmark.allLowerBounds
    ? "Here \\(\\frac{4}{3}\\) is the proved limit of distinguished-pair lower bounds. This certifies the asymptotic threshold even though those pairs have not been proved to maximize the full invariant throughout the families."
    : "At least one leader supplies a proof of the full invariant at this value.";

  clearMath(detailContent);
  detailContent.innerHTML = `
    <div class="detail-kicker">
      <span class="claim-badge ${featuredBenchmark.allLowerBounds ? "lower-bound" : "exact"}">
        current overall benchmark
      </span>
      <span class="verification-badge">${escapeHtml(
        featuredBenchmark.attainmentLabel,
      )}</span>
    </div>
    <h2 class="detail-title">The score to beat</h2>
    <p class="detail-lede">
      This compares every individually cataloged finite value, every displayed
      finite family member, and every proved family limit in the current record book.
    </p>
    <div class="detail-value">
      <span>${alphaBarMarkup} =</span>
      <strong>${texInline(featuredBenchmark.score.tex)}</strong>
      <span>≈ ${formatDecimal(featuredBenchmark.score.value, 7)}</span>
    </div>
    <div class="detail-grid">
      <div><span>Attainment</span><strong>${escapeHtml(
        featuredBenchmark.attainmentLabel,
      )}</strong></div>
      <div><span>Evidence</span><strong>${featuredBenchmark.allLowerBounds ? "Lower-bound limits" : "Exact value"}</strong></div>
      <div><span>Leading entries</span><strong>${representativeLeaders.length}</strong></div>
    </div>
    <section class="detail-section">
      <span class="detail-section-label">Interpretation</span>
      <h4>${escapeHtml(attainmentCopy)}</h4>
      <p>${proseMarkup(evidenceCopy)}</p>
      <p>
        A single finite matroid with ${alphaBarMarkup} &gt;
        ${texInline(featuredBenchmark.score.tex)} beats the record on the
        nose. A proved family limit above it beats the asymptotic record.
      </p>
    </section>
    <section class="detail-section">
      <span class="detail-section-label">Entries at this threshold</span>
      <div class="benchmark-list">${leaderRows}</div>
    </section>
  `;
  showDialog("record:overall");
  if (!initialRender) typesetMath([detailContent]);

  detailContent.querySelectorAll("[data-benchmark-leader]").forEach((button) => {
    button.addEventListener("click", () => {
      const leader = representativeLeaders[Number(button.dataset.benchmarkLeader)];
      if (leader.family) openFamily(leader.family.id);
      else openMatroid(leader.matroid.id);
    });
  });
}

function openMatroid(id) {
  const matroid = matroids.find((entry) => entry.id === id);
  if (!matroid) return;
  const pairSection = matroid.ratioCounts
    ? `
      <section class="detail-section">
        <span class="detail-section-label">Maximizing-pair certificate</span>
        <h4>Pair {${escapeHtml(matroid.maximizingPair.join(", "))}}</h4>
        <p>
          The four exact basis counts are
          (${matroid.ratioCounts.map(escapeHtml).join(", ")}), which give
          ${texInline(matroid.exact.tex)}. The maximum occurs for
          ${escapeHtml(matroid.maximizingPairCount)} eligible
          ${matroid.maximizingPairCount === 1 ? "pair" : "pairs"}.
        </p>
      </section>
    `
    : "";

  clearMath(detailContent);
  detailContent.innerHTML = `
    <div class="detail-kicker">
      <span class="claim-badge exact">exact finite value</span>
      <span class="verification-badge">${escapeHtml(
        statusLabels[matroid.verificationStatus] || matroid.verificationStatus,
      )}</span>
    </div>
    <h2 class="detail-title">${escapeHtml(matroid.name)}</h2>
    <p class="detail-lede">${proseMarkup(matroid.summary)}</p>
    <div class="detail-value">
      <span>${alphaBarMarkup} =</span>
      <strong>${texInline(matroid.exact.tex)}</strong>
      <span>≈ ${formatDecimal(matroid.exact.value, 7)}</span>
    </div>
    <div class="detail-grid">
      <div><span>Ground set</span><strong>${matroid.n}</strong></div>
      <div><span>Rank</span><strong>${matroid.rank}</strong></div>
      <div><span>Bases</span><strong>${matroid.bases ?? "—"}</strong></div>
    </div>
    <section class="detail-section">
      <span class="detail-section-label">Construction</span>
      <h4>${escapeHtml(matroid.representationType)}</h4>
      <p>${proseMarkup(matroid.construction)}</p>
      <div class="field-badges">${formatFields(matroid.fields)}</div>
    </section>
    ${pairSection}
    ${matrixMarkup(matroid.matrix)}
    <section class="detail-section">
      <span class="detail-section-label">Credit and provenance</span>
      <h4>${escapeHtml(matroid.contributors.join(", "))}</h4>
      <p><strong>Discovery date:</strong> ${escapeHtml(matroid.discoveryDate)}</p>
      <p>${proseMarkup(matroid.provenance)}</p>
      <p><strong>AI disclosure:</strong> ${proseMarkup(matroid.aiDisclosure)}</p>
    </section>
  `;
  showDialog("matroid:" + matroid.id);
  if (!initialRender) typesetMath([detailContent]);
}

const familyPointTable = (family) => {
  const points = family.series
    .flatMap((series) =>
      series.points.map((point) => ({
        ...point,
        seriesLabel: series.label,
      })),
    )
    .sort((a, b) => a.n - b.n);
  const shown = points.slice(0, 14);
  return `
    <div class="matrix-wrap">
      <table>
        <thead>
          <tr><th>Series</th><th>Parameter</th><th>|E|</th><th>Rank</th><th>Displayed value</th></tr>
        </thead>
        <tbody>
          ${shown
            .map(
              (point) => `
                <tr>
                  <td>${parameterMarkup(point.seriesLabel)}</td>
                  <td>${parameterMarkup(point.parameter)}</td>
                  <td>${point.n}</td>
                  <td>${point.rank}</td>
                  <td class="exact-cell">${texInline(point.exact.tex)}</td>
                </tr>
              `,
            )
            .join("")}
        </tbody>
      </table>
      ${points.length > shown.length ? `<p>Showing the first ${shown.length} of ${points.length} plotted values.</p>` : ""}
    </div>
  `;
};

function openFamily(id, seriesId = null, selectedPoint = null) {
  const family = families.find((entry) => entry.id === id);
  if (!family) return;
  const selectedSeries = seriesId
    ? family.series.find((series) => series.id === seriesId)
    : null;
  const valueLabel =
    family.claimType === "exact" && family.supremumKind === "attained"
      ? "exact value ="
      : family.supremumKind === "iterated limit"
        ? "iterated curve limit ="
        : "curve limit =";
  const verifiedFieldMarkup = family.fields.length
    ? `<div class="field-badges">${formatFields(family.fields)}</div>`
    : "";
  const characteristicMarkup = family.characteristics?.length
    ? `
      <div class="field-badges characteristic-badges">
        ${formatCharacteristics(family.characteristics)}
      </div>
      <p>${proseMarkup(family.representationStatement)}</p>
    `
    : "";
  const selectedMarkup = selectedPoint
    ? `
      <div class="detail-grid">
        <div><span>Selected parameter</span><strong>${parameterMarkup(selectedPoint.parameter)}</strong></div>
        <div><span>${family.claimType === "exact" ? "Selected exact value" : "Selected lower bound"}</span><strong>${texInline(selectedPoint.exact.tex)}</strong></div>
        <div><span>Ground set / rank</span><strong>${selectedPoint.n} / ${selectedPoint.rank}</strong></div>
      </div>
    `
    : `
      <div class="detail-grid">
        <div><span>Parameter</span><strong>${proseMarkup(family.parameter)}</strong></div>
        <div><span>Curve series</span><strong>${family.series.length}</strong></div>
        <div><span>Claim type</span><strong>${family.claimType === "exact" ? "Exact" : "Lower bound"}</strong></div>
      </div>
    `;
  const isExternal = /^https?:\/\//.test(family.sourceUrl);
  const sourceHref = isExternal ? family.sourceUrl : "./" + family.sourceUrl;

  clearMath(detailContent);
  detailContent.innerHTML = `
    <div class="detail-kicker">
      <span class="claim-badge ${family.claimType}">${escapeHtml(
        claimLabels[family.claimType],
      )}</span>
      <span class="verification-badge">${escapeHtml(
        statusLabels[family.verificationStatus] || family.verificationStatus,
      )}</span>
    </div>
    <h2 class="detail-title">${escapeHtml(family.name)}</h2>
    <p class="detail-lede">${proseMarkup(family.summary)}</p>
    <div class="detail-value">
      <span>${valueLabel}</span>
      <strong>${texInline(family.supremum.tex)}</strong>
      <span>${escapeHtml(family.supremumKind)}</span>
    </div>
    ${selectedMarkup}
    <section class="detail-section">
      <span class="detail-section-label">Construction</span>
      <h4>${texInline(family.sizeRankFormula)}</h4>
      <p>${proseMarkup(family.constructionDetails)}</p>
      ${verifiedFieldMarkup}
      ${characteristicMarkup}
    </section>
    <section class="detail-section">
      <span class="detail-section-label">What the curve proves</span>
      <h4>${texInline(family.displayedFormula)}</h4>
      <p>${proseMarkup(family.curveExplanation)}</p>
    </section>
    <section class="detail-section">
      <span class="detail-section-label">Proof status</span>
      <h4>${escapeHtml(
        statusLabels[family.verificationStatus] || family.verificationStatus,
      )}</h4>
      <p>${proseMarkup(family.proofStatus)}</p>
    </section>
    <section class="detail-section">
      <span class="detail-section-label">Plotted values</span>
      <h4>${escapeHtml(selectedSeries ? selectedSeries.label : "All series")}</h4>
      ${familyPointTable(
        selectedSeries ? { ...family, series: [selectedSeries] } : family,
      )}
    </section>
    <section class="detail-section">
      <span class="detail-section-label">Credit and proof source</span>
      <h4>${escapeHtml(family.contributors.join(", "))}</h4>
      <p><strong>Discovery date:</strong> ${escapeHtml(family.discoveryDate)}</p>
      <p><strong>AI disclosure:</strong> ${proseMarkup(family.aiDisclosure)}</p>
      <a class="detail-link" href="${escapeHtml(sourceHref)}" ${isExternal ? 'target="_blank" rel="noreferrer"' : ""}>
        ${escapeHtml(family.sourceLabel || "Open the cited source")} →
      </a>
    </section>
  `;
  showDialog("family:" + family.id);
  if (!initialRender) typesetMath([detailContent]);
}

const closeDialog = () => {
  if (detailDialog.open && typeof detailDialog.close === "function") {
    detailDialog.close();
  } else {
    detailDialog.removeAttribute("open");
  }
  updateUrl();
};

const render = () => {
  renderChart();
  renderRecords();
  document.body.dataset.visibleMatroids = String(matroids.filter(matroidMatches).length);
};

const resetFilters = () => {
  Object.assign(state, defaults);
  state.hiddenSeries.clear();
  writeStateToControls();
  updateUrl();
  render();
};

const inferGitHubRepository = () => {
  if (siteConfig.githubRepositoryUrl) {
    return siteConfig.githubRepositoryUrl.replace(/\/$/, "");
  }
  if (!window.location.hostname.endsWith(".github.io")) return null;
  const owner = window.location.hostname.slice(0, -".github.io".length);
  const [repository] = window.location.pathname.split("/").filter(Boolean);
  return owner && repository ? `https://github.com/${owner}/${repository}` : null;
};

const configureSubmissionLinks = () => {
  const repository = inferGitHubRepository();
  if (!repository) return;
  document.querySelectorAll(".github-submission-link").forEach((link) => {
    link.href =
      repository +
      "/issues/new?template=" +
      encodeURIComponent(link.dataset.issueTemplate);
  });
};

const copyView = async () => {
  updateUrl();
  const shareUrl = window.location.href;
  try {
    await navigator.clipboard.writeText(shareUrl);
    showToast("This filtered view was copied.");
  } catch {
    const input = document.createElement("textarea");
    input.value = shareUrl;
    input.setAttribute("readonly", "");
    input.style.position = "fixed";
    input.style.opacity = "0";
    document.body.append(input);
    input.select();
    document.execCommand("copy");
    input.remove();
    showToast("This filtered view was copied.");
  }
};

Object.values(controls).forEach((control) => {
  if (!(control instanceof HTMLElement) || control === controls.maxNOutput) return;
  const eventName =
    control === controls.search || control === controls.maxN ? "input" : "change";
  control.addEventListener(eventName, () => {
    syncStateFromControls();
    updateUrl();
    render();
  });
});

document.querySelector("#reset-filters").addEventListener("click", resetFilters);
document.querySelector("#copy-view").addEventListener("click", copyView);
document.querySelector("#toggle-x-axis").addEventListener("click", () => {
  state.xAxis = state.xAxis === "rank" ? "size" : "rank";
  writeStateToControls();
  updateUrl();
  render();
});
document.querySelector("#dialog-close").addEventListener("click", closeDialog);
document
  .querySelector("#hero-record-action")
  .addEventListener("click", openFeaturedBenchmark);
detailDialog.addEventListener("click", (event) => {
  if (event.target === detailDialog) closeDialog();
});
detailDialog.addEventListener("cancel", (event) => {
  event.preventDefault();
  closeDialog();
});

setInitialMetrics();
configureSubmissionLinks();
populateRanks();
readUrlState();
writeStateToControls();
renderFamilyCards();
renderChallenges();
render();

const requestedDetail = new URLSearchParams(window.location.search).get("detail");
if (requestedDetail) {
  const [kind, id] = requestedDetail.split(":");
  if (kind === "matroid") openMatroid(id);
  if (kind === "family") openFamily(id);
  if (kind === "record") openFeaturedBenchmark();
}

document.documentElement.dataset.ready = "true";

// This pass is queued behind the persistent page-ready promise declared in
// index.html, so it works whether MathJax or the application initializes first.
initialRender = false;
typesetDocument();
