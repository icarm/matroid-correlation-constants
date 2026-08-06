const gcd = (a, b) => {
  let x = Math.abs(a);
  let y = Math.abs(b);
  while (y) {
    [x, y] = [y, x % y];
  }
  return x || 1;
};

export const fraction = (numerator, denominator) => {
  const divisor = gcd(numerator, denominator);
  const num = numerator / divisor;
  const den = denominator / divisor;
  return {
    numerator: num,
    denominator: den,
    label: den === 1 ? String(num) : num + "/" + den,
    tex: den === 1 ? String(num) : "\\frac{" + num + "}{" + den + "}",
    value: num / den,
  };
};

export const siteConfig = {
  title: "Matroid Correlation Constants",
  dataVersion: "public beta · revised 2026-08-04",
  supportedFields: [2, 3, 5, 7],
  // Set this for a non-GitHub-Pages deployment. GitHub Pages URLs are inferred.
  githubRepositoryUrl: "https://github.com/icarm/matroid-correlation-constants",
};

const spikeMembers = [
  {
    id: "hsw-spike-p2",
    name: "Finite-field spike M₂⁵",
    field: 2,
    n: 10,
    rank: 5,
    bases: 136,
  },
  {
    id: "hsw-spike-p3",
    name: "Finite-field spike M₃⁵",
    field: 3,
    n: 14,
    rank: 5,
    bases: 891,
  },
  {
    id: "hsw-spike-p5",
    name: "Finite-field spike M₅⁵",
    field: 5,
    n: 22,
    rank: 5,
    bases: 9625,
  },
  {
    id: "hsw-spike-p7",
    name: "Finite-field spike M₇⁵",
    field: 7,
    n: 30,
    rank: 5,
    bases: 46991,
  },
];

export const matroids = [
  {
    id: "ternary-100-81",
    name: "Ternary rank-6 benchmark",
    shortName: "100/81 benchmark",
    n: 12,
    rank: 6,
    exact: fraction(100, 81),
    fields: [3],
    familyId: null,
    verificationStatus: "computationally-checked",
    recordClass: "field",
    bases: 684,
    density: 57 / 77,
    maximizingPair: ["8", "11"],
    maximizingPairCount: 1,
    ratioCounts: [180, 162, 162, 180],
    representationType: "matrix",
    construction:
      "A rank-6 matroid on twelve columns over \\(\\operatorname{GF}(3)\\), found independently in two searches.",
    summary:
      "Exact enumeration of all 924 six-column subsets gives 684 bases and the maximizing table (180, 162, 162, 180).",
    contributors: ["Chris Eur", "David Renshaw", "June Huh"],
    discoveryDate: "August 2026",
    aiDisclosure:
      "This matroid was found independently in two AI-assisted searches. Chris Eur and David Renshaw used AlphaEvolve (the exact system version was not recorded here) to search for the example. June Huh used ChatGPT 5.5 Pro as an aid while studying Mathieu groups. No public chat link is currently recorded.",
    provenance:
      "Chris Eur and David Renshaw found this example with AlphaEvolve. June Huh found it independently through the study of Mathieu groups, aided by ChatGPT 5.5 Pro. Huh further identified its relation to \\(S(3,4,10)\\), duads, and synthemes.",
    matrix: [
      [1, 2, 1, 2, 2, 2, 1, 1, 0, 0, 1, 2],
      [0, 0, 2, 0, 0, 0, 0, 0, 2, 1, 1, 1],
      [0, 1, 1, 1, 0, 1, 1, 2, 1, 1, 1, 2],
      [1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 0, 1],
      [0, 1, 0, 1, 2, 1, 1, 0, 2, 0, 1, 0],
      [0, 1, 1, 1, 1, 0, 2, 0, 0, 1, 0, 0],
    ],
  },
  ...spikeMembers.map((member) => ({
    ...member,
    shortName: member.name,
    exact: fraction(8, 7),
    fields: [member.field],
    familyId: "hsw-finite-field-spikes",
    verificationStatus: "literature-verified",
    recordClass: "field",
    density: null,
    maximizingPair: null,
    maximizingPairCount: null,
    ratioCounts: null,
    representationType: "finite-field construction",
    construction:
      "The rank-5 finite-field spike construction of Huh, Schröter, and Wang.",
    summary:
      "The project independently recomputed the full unweighted maximum from all bases for this displayed member.",
    contributors: ["June Huh", "Benjamin Schröter", "Botong Wang"],
    discoveryDate: "June 2018",
    aiDisclosure: "No AI use is reported in the cited discovery record.",
    provenance: "Huh–Schröter–Wang, Section 5.",
    matrix: null,
  })),
];

const uniformExtensionPoints = Array.from({ length: 29 }, (_, index) => {
  const r = index + 2;
  return {
    parameter: "r = " + r,
    n: 4 * r + 2,
    rank: 2 * r + 1,
    exact: fraction(4 * r * r, 3 * r * r + 2 * r + 1),
  };
});

const spikeCurvePoints = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29].map(
  (prime) => ({
    parameter: "p = " + prime,
    field: prime,
    n: 4 * prime + 2,
    rank: 5,
    exact: fraction(8, 7),
  }),
);

const affineSeries = [
  {
    id: "affine-q2",
    label: "q = 2",
    baseField: 2,
    points: [
      { parameter: "rank(A) = 3", n: 10, rank: 7, exact: fraction(6, 7) },
      { parameter: "rank(A) = 4", n: 18, rank: 9, exact: fraction(8, 7) },
      { parameter: "rank(A) = 5", n: 34, rank: 11, exact: fraction(80, 67) },
      { parameter: "rank(A) = 6", n: 66, rank: 13, exact: fraction(6, 5) },
      {
        parameter: "rank(A) = 8",
        n: 258,
        rank: 17,
        exact: fraction(1168, 977),
      },
    ],
  },
  {
    id: "affine-q3",
    label: "q = 3",
    baseField: 3,
    points: [
      { parameter: "rank(A) = 3", n: 20, rank: 7, exact: fraction(42, 37) },
      { parameter: "rank(A) = 4", n: 56, rank: 9, exact: fraction(6, 5) },
      {
        parameter: "rank(A) = 5",
        n: 164,
        rank: 11,
        exact: fraction(265, 218),
      },
    ],
  },
  {
    id: "affine-q5",
    label: "q = 5",
    baseField: 5,
    points: [
      {
        parameter: "rank(A) = 3",
        n: 52,
        rank: 7,
        exact: fraction(150, 127),
      },
      {
        parameter: "rank(A) = 4",
        n: 252,
        rank: 9,
        exact: fraction(1168, 959),
      },
    ],
  },
  {
    id: "affine-q7",
    label: "q = 7",
    baseField: 7,
    points: [
      {
        parameter: "rank(A) = 3",
        n: 100,
        rank: 7,
        exact: fraction(306, 257),
      },
      {
        parameter: "rank(A) = 4",
        n: 688,
        rank: 9,
        exact: fraction(104, 85),
      },
    ],
  },
];

const projectiveSeries = [
  {
    id: "projective-q2",
    label: "q = 2",
    baseField: 2,
    points: [
      { parameter: "rank(PG) = 3", n: 16, rank: 7, exact: fraction(10, 9) },
      { parameter: "rank(PG) = 4", n: 32, rank: 9, exact: fraction(128, 109) },
      { parameter: "rank(PG) = 5", n: 64, rank: 11, exact: fraction(70, 59) },
      { parameter: "rank(PG) = 6", n: 128, rank: 13, exact: fraction(297, 250) },
      { parameter: "rank(PG) = 8", n: 512, rank: 17, exact: fraction(7456, 6275) },
    ],
  },
  {
    id: "projective-q3",
    label: "q = 3",
    baseField: 3,
    points: [
      { parameter: "rank(PG) = 3", n: 28, rank: 7, exact: fraction(36, 31) },
      { parameter: "rank(PG) = 4", n: 82, rank: 9, exact: fraction(256, 213) },
      { parameter: "rank(PG) = 5", n: 244, rank: 11, exact: fraction(1640, 1351) },
      { parameter: "rank(PG) = 6", n: 730, rank: 13, exact: fraction(12528, 10261) },
    ],
  },
  {
    id: "projective-q5",
    label: "q = 5",
    baseField: 5,
    points: [
      { parameter: "rank(PG) = 3", n: 64, rank: 7, exact: fraction(32, 27) },
      { parameter: "rank(PG) = 4", n: 314, rank: 9, exact: fraction(2944, 2417) },
      { parameter: "rank(PG) = 5", n: 1564, rank: 11, exact: fraction(3200, 2593) },
    ],
  },
  {
    id: "projective-q7",
    label: "q = 7",
    baseField: 7,
    points: [
      { parameter: "rank(PG) = 3", n: 116, rank: 7, exact: fraction(180, 151) },
      { parameter: "rank(PG) = 4", n: 802, rank: 9, exact: fraction(7296, 5963) },
    ],
  },
];

const steinerTriplePoints = Array.from({ length: 68 }, (_, index) => index + 7)
  .filter((n) => n % 6 === 1 || n % 6 === 3)
  .map((n) => ({
    parameter: "n = " + n,
    n: 2 * n + 2,
    rank: 7,
    exact: fraction(6 * (n - 2), 5 * n - 8),
  }));

const steinerQuadruplePoints = Array.from({ length: 67 }, (_, index) => index + 8)
  .filter((n) => n % 6 === 2 || n % 6 === 4)
  .map((n) => ({
    parameter: "n = " + n,
    n: 2 * n + 2,
    rank: 9,
    exact: fraction(16 * (n - 3), 13 * n - 34),
  }));

export const families = [
  {
    id: "hsw-finite-field-spikes",
    name: "Huh–Schröter–Wang finite-field spikes",
    shortName: "HSW spikes",
    claimType: "exact",
    verificationStatus: "literature-verified",
    color: "#8c3d2f",
    parameter: "prime \\(p\\)",
    displayedFormula: "\\overline{\\alpha}(M_p^5) = \\frac{8}{7}",
    sizeRankFormula:
      "|E(M_p^5)| = 4p + 2, \\qquad \\operatorname{rk}(M_p^5) = 5",
    supremum: fraction(8, 7),
    supremumKind: "attained",
    fields: [2, 3, 5, 7],
    contributors: ["June Huh", "Benjamin Schröter", "Botong Wang"],
    discoveryDate: "June 2018",
    aiDisclosure: "No AI use is reported in the cited discovery record.",
    summary:
      "A rank-5 family over \\(\\operatorname{GF}(p)\\) whose unweighted correlation ratio is exactly \\(\\frac{8}{7}\\) for every displayed prime \\(p\\).",
    constructionDetails:
      "For each prime \\(p\\), Huh, Schröter, and Wang define the finite-field spike \\(M_p^5\\) over \\(\\operatorname{GF}(p)\\). It has rank \\(5\\) and \\(4p+2\\) elements. Thus the curve consists of genuine finite matroids at the admissible prime parameters, not interpolated points.",
    curveExplanation:
      "The full maximum over eligible element pairs is \\(\\frac{8}{7}\\) for every member, so this is a horizontal solid curve. The value is attained on the nose by each finite member; it is not merely a limiting value.",
    proofStatus:
      "The exact family value is proved in the cited paper. For \\(p=2,3,5,7\\), this project also reconstructed every basis and independently recomputed the full unweighted maximum.",
    sourceUrl: "https://doi.org/10.4171/JEMS/1119",
    sourceLabel:
      "Huh–Schröter–Wang, Correlation bounds for fields and matroids, JEMS 24 (2022)",
    series: [
      {
        id: "hsw-primes",
        label: "Mₚ⁵",
        field: null,
        points: spikeCurvePoints,
      },
    ],
  },
  {
    id: "uniform-self-sum-extensions",
    name: "Uniform self-sum extensions",
    shortName: "Uniform extensions",
    claimType: "lower-bound",
    verificationStatus: "proof-reviewed",
    color: "#176b72",
    parameter: "integer \\(r\\ge 2\\)",
    displayedFormula:
      "R_{ef}(P_r) = \\frac{4r^2}{3r^2+2r+1}",
    sizeRankFormula:
      "|E(P_r)| = 4r+2, \\qquad \\operatorname{rk}(P_r) = 2r+1",
    supremum: fraction(4, 3),
    supremumKind: "approached",
    fields: [],
    contributors: ["Alexander Divoux", "Shouda Wang"],
    discoveryDate: "August 2026",
    aiDisclosure:
      "Alexander Divoux and Shouda Wang used ChatGPT 5.6 Sol Ultra to assist the discovery of the original transversal-matroid family. No public chat link is currently recorded.",
    summary:
      "A finite matroid for every integer \\(r\\ge2\\), with a certified distinguished-pair value tending to \\(\\frac{4}{3}\\) from below.",
    constructionDetails:
      "Start with two copies of \\(U_{r,2r}\\), take their direct sum, freely extend by \\(e\\), and then freely coextend by \\(f\\). The resulting matroid \\(P_r\\) has \\(4r+2\\) elements and rank \\(2r+1\\).",
    curveExplanation:
      "Exact basis counts for the distinguished pair \\((e,f)\\) give \\(\\frac{4r^2}{3r^2+2r+1}\\). Hence every plotted point is a certified lower bound for the finite matroid \\(P_r\\), and these finite lower bounds approach \\(\\frac{4}{3}\\) as \\(r\\to\\infty\\). No finite \\(r\\) attains \\(\\frac{4}{3}\\) through this formula.",
    proofStatus:
      "Alexander Divoux and Shouda Wang first found this family with the aid of ChatGPT 5.6 Sol Ultra. Its reinterpretation as a double free-extension is due to humans. The adjacent-rank identity proves the displayed pair value and its limit; maximization over all pairs remains open.",
    sourceUrl: "mathematics.html#uniform-family",
    sourceLabel: "Proof: uniform self-sum extensions",
    series: [
      {
        id: "uniform-r",
        label: "Pᵣ",
        field: null,
        points: uniformExtensionPoints,
      },
    ],
  },
  {
    id: "affine-self-sum-extensions",
    name: "Affine-geometry self-sum extensions",
    shortName: "Affine extensions",
    claimType: "lower-bound",
    verificationStatus: "proof-reviewed",
    color: "#6d4c93",
    parameter: "integer \\(d\\ge2\\) and prime power \\(q\\)",
    displayedFormula:
      "\\lim_{d\\to\\infty}R_{ef}(P_{d,q}) = \\frac{4q^2}{3q^2+1}",
    sizeRankFormula:
      "|E(P_{d,q})| = 2q^{d-1}+2, \\qquad \\operatorname{rk}(P_{d,q}) = 2d+1",
    supremum: fraction(4, 3),
    supremumKind: "iterated limit",
    fields: [],
    baseFields: [2, 3, 5, 7],
    characteristics: [2, 3, 5, 7],
    contributors: ["Chris Eur"],
    discoveryDate: "August 2026",
    aiDisclosure:
      "Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the affine-geometry family through the double-free construction and the common 2-design mechanism. A public chat link is not currently recorded.",
    summary:
      "Affine-geometry self-sums give characteristic-indexed lower-bound curves whose iterated limit is \\(\\frac{4}{3}\\).",
    constructionDetails:
      "Let \\(A=\\operatorname{AG}(d-1,q)\\), of rank \\(d\\) on \\(q^{d-1}\\) points, and form \\(P_{d,q}=(A\\oplus A)+e\\times f\\). The free extension and coextension may require passing from \\(\\operatorname{GF}(q)\\) to a finite extension field, but the resulting matroid remains representable in characteristic \\(p\\) when \\(q=p^a\\).",
    representationStatement:
      "For \\(q=p^a\\), every displayed member has a representation over some finite extension \\(\\operatorname{GF}(q^k)\\), hence in characteristic \\(p\\). Characteristic badges are deliberately distinct from exact \\(\\operatorname{GF}(p)\\) certificates.",
    curveExplanation:
      "Möbius inversion on the affine-flat lattice gives every plotted value exactly. For fixed \\(q\\), they tend to \\(\\frac{4q^2}{3q^2+1}\\) as \\(d\\to\\infty\\). For fixed \\(d\\), they tend to \\(\\frac{4d}{3d+1}\\) as \\(q\\to\\infty\\). Either subsequent limit approaches \\(\\frac43\\). The curves are dashed because they certify distinguished-pair lower bounds rather than the full maximizing value.",
    proofStatus:
      "Chris Eur discovered the affine, projective, and Steiner-system constructions with the aid of ChatGPT 5.6 Sol Max on Codex, using the double-free construction. Their shared starting point is a base matroid whose bases form a 2-design. Exact finite counts and both limits are proved on the mathematics page; maximization over every pair remains open.",
    sourceUrl: "mathematics.html#geometry-families",
    sourceLabel: "Proof: affine-geometry self-sum extensions",
    series: affineSeries,
  },
  {
    id: "projective-self-sum-extensions",
    name: "Projective-geometry self-sum extensions",
    shortName: "Projective extensions",
    claimType: "lower-bound",
    verificationStatus: "proof-reviewed",
    color: "#b5652a",
    parameter: "integer \\(d\\ge2\\) and prime power \\(q\\)",
    displayedFormula:
      "\\lim_{d\\to\\infty}R_{ef}(P_{d,q}) = \\frac{4q^2}{3q^2+1}",
    sizeRankFormula:
      "|E(P_{d,q})| = 2\\frac{q^d-1}{q-1}+2, \\qquad \\operatorname{rk}(P_{d,q}) = 2d+1",
    supremum: fraction(4, 3),
    supremumKind: "iterated limit",
    fields: [],
    characteristics: [2, 3, 5, 7],
    contributors: ["Chris Eur"],
    discoveryDate: "August 2026",
    aiDisclosure:
      "Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the projective-geometry family through the double-free construction and the common 2-design mechanism. A public chat link is not currently recorded.",
    summary:
      "Projective-geometry self-sums give characteristic-indexed lower-bound curves with the same two limiting regimes as affine geometries.",
    constructionDetails:
      "Let \\(G=\\operatorname{PG}(d-1,q)\\), of rank \\(d\\) on \\((q^d-1)/(q-1)\\) points, and form \\(P_{d,q}=(G\\oplus G)+e\\times f\\). A field extension may be necessary to carry out the free extension and coextension.",
    representationStatement:
      "When \\(q=p^a\\), the construction is representable over a suitable finite extension of \\(\\operatorname{GF}(q)\\), hence in characteristic \\(p\\).",
    curveExplanation:
      "Möbius inversion on the projective-flat lattice gives every plotted value exactly. For fixed \\(q\\), the values tend to \\(4q^2/(3q^2+1)\\); for fixed \\(d\\) and growing \\(q\\), they tend to \\(4d/(3d+1)\\). A subsequent limit approaches \\(4/3\\).",
    proofStatus:
      "Chris Eur discovered this family with the aid of ChatGPT 5.6 Sol Max on Codex, using the double-free construction and the 2-design property. The displayed pair is certified exactly; full maximization remains open.",
    sourceUrl: "mathematics.html#geometry-families",
    sourceLabel: "Proof: affine and projective geometry families",
    series: projectiveSeries,
  },
  {
    id: "steiner-system-self-sum-extensions",
    name: "Steiner-system sparse-paving extensions",
    shortName: "Steiner extensions",
    claimType: "lower-bound",
    verificationStatus: "proof-reviewed",
    color: "#34745b",
    parameter: "Steiner systems \\(S(r-1,r,n)\\)",
    displayedFormula:
      "R_{ef}(P_{r,n}) = \\frac{4r(n-r+1)}{(3r+1)(n-r)+4r+2}",
    sizeRankFormula:
      "|E(P_{r,n})| = 2n+2, \\qquad \\operatorname{rk}(P_{r,n}) = 2r+1",
    supremum: fraction(4, 3),
    supremumKind: "iterated limit",
    fields: [],
    contributors: ["Chris Eur"],
    discoveryDate: "August 2026",
    aiDisclosure:
      "Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the Steiner-system family through the double-free construction and the common 2-design mechanism. A public chat link is not currently recorded.",
    summary:
      "Sparse-paving matroids from Steiner systems give nonuniform 2-design bases and distinguished-pair values approaching \\(4/3\\).",
    constructionDetails:
      "Take the blocks of a Steiner system \\(S(r-1,r,n)\\) as the circuit-hyperplanes of a rank-\\(r\\) sparse-paving matroid \\(M_{r,n}\\), then form \\(P_{r,n}=(M_{r,n}\\oplus M_{r,n})+e\\times f\\). The plotted series use Steiner triple and quadruple systems, whose admissible orders are explicit.",
    curveExplanation:
      "For fixed \\(r\\), the formula tends to \\(4r/(3r+1)\\) as \\(n\\to\\infty\\); those limits tend to \\(4/3\\) as \\(r\\to\\infty\\). The visible series are \\(S(2,3,n)\\) and \\(S(3,4,n)\\); Keevash's design-existence theorem supplies the general fixed-rank families at all sufficiently large admissible orders.",
    proofStatus:
      "Chris Eur discovered this family with the aid of ChatGPT 5.6 Sol Max on Codex, using the double-free construction and the common 2-design property. The adjacent-rank counts prove the displayed pair value exactly; full maximization remains open.",
    sourceUrl: "mathematics.html#steiner-family",
    sourceLabel: "Proof: Steiner-system sparse-paving family",
    series: [
      {
        id: "steiner-triples",
        label: "S(2,3,n)",
        field: null,
        points: steinerTriplePoints,
      },
      {
        id: "steiner-quadruples",
        label: "S(3,4,n)",
        field: null,
        points: steinerQuadruplePoints,
      },
    ],
  },
];

export const challenges = [
  {
    id: "beat-on-the-nose",
    eyebrow: "On the nose",
    title: "Achieve at least \\(\\frac{4}{3}\\) with one finite matroid",
    description:
      "Find a finite matroid \\(M\\) and certify that its full unweighted correlation ratio is at least \\(\\frac{4}{3}\\).",
    target: "\\overline{\\alpha}(M) \\geq \\frac{4}{3}",
  },
  {
    id: "beat-in-the-limit",
    eyebrow: "In the limit",
    title: "Reach at least \\(\\frac{4}{3}\\) asymptotically",
    description:
      "Give a precisely defined family whose proved exact values or certified lower bounds have limiting supremum at least \\(\\frac{4}{3}\\).",
    target:
      "\\limsup_{t\\to\\infty}\\overline{\\alpha}(M_t) \\geq \\frac{4}{3}",
  },
  {
    id: "finite-field-records",
    eyebrow: "By representation",
    title: "Improve a finite-field record",
    description:
      "Improve any field-specific exact record with a computer-ready representation over that field. Missing badges are not evidence of nonrepresentability.",
    target: "\\operatorname{GF}(q)\\text{ leaderboards}",
    showFieldRecords: true,
  },
];
