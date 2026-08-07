-- Families move from the hardcoded src/familyData.ts catalog into D1, so
-- proposals can arrive through the site. Rows are proposals with a status:
-- 'pending' on submission, then 'accepted' (public: chart curve, card,
-- page) or 'rejected' after review by an admin — family claims carry
-- proofs, so acceptance is a human decision, never automatic.
--
-- Prose and formula columns hold TeX for MathJax and are rendered
-- HTML-escaped. series_json is the plotted members:
--   [{id, label, points: [{parameter, n, rank, num, den, field?}]}]
-- The five curated families are seeded below (generated from the catalog
-- module this migration replaces); they keep handwritten ai_disclosure
-- prose, while proposals carry the structured AI-use fields instead.

ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS families (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  name TEXT NOT NULL,
  short TEXT NOT NULL,               -- chart legend / compact label
  claim TEXT NOT NULL CHECK (claim IN ('exact', 'lower')),
  color TEXT,                        -- assigned at acceptance
  fields_json TEXT NOT NULL DEFAULT '[]',  -- fields with verified members
  parameter TEXT NOT NULL,
  formula_tex TEXT NOT NULL,
  size_rank_tex TEXT NOT NULL,
  supremum_num INTEGER NOT NULL,
  supremum_den INTEGER NOT NULL,
  supremum_kind TEXT NOT NULL
    CHECK (supremum_kind IN ('attained', 'approached', 'iterated limit')),
  contributors TEXT NOT NULL,
  discovery_date TEXT NOT NULL,
  ai_used INTEGER,                   -- structured declaration (proposals)
  ai_model TEXT,
  ai_role TEXT,
  ai_chat_url TEXT,
  ai_disclosure TEXT,                -- handwritten prose (curated rows)
  summary TEXT NOT NULL,
  construction TEXT NOT NULL,
  curve_explanation TEXT NOT NULL,
  proof_status TEXT NOT NULL,
  proof_url TEXT,                    -- proof or stable reference link
  math_anchor TEXT,                  -- /mathematics#anchor, curated only
  series_json TEXT NOT NULL,
  submitter_user_id INTEGER REFERENCES users(id),
  submitted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by INTEGER REFERENCES users(id),
  reviewed_at TEXT,
  review_note TEXT
);

CREATE INDEX IF NOT EXISTS idx_families_status ON families (status);

INSERT INTO families
  (slug, status, name, short, claim, color, fields_json, parameter,
   formula_tex, size_rank_tex, supremum_num, supremum_den, supremum_kind,
   contributors, discovery_date, ai_disclosure, summary, construction,
   curve_explanation, proof_status, math_anchor, series_json)
VALUES
  ('hsw-finite-field-spikes', 'accepted', 'Huh–Schröter–Wang finite-field spikes', 'HSW spikes', 'exact', '#8c3d2f',
   '[2,3,5,7]', 'prime \(p\)',
   '\overline{\alpha}(M_p^5) = \frac{8}{7}',
   '|E(M_p^5)| = 4p + 2, \qquad \operatorname{rk}(M_p^5) = 5',
   8, 7, 'attained',
   'June Huh, Benjamin Schröter, Botong Wang', 'June 2018',
   'No AI use is reported in the cited discovery record.',
   'A rank-5 family over \(\operatorname{GF}(p)\) whose correlation constant is exactly \(\frac{8}{7}\) for every displayed prime \(p\).',
   'For each prime \(p\), Huh, Schröter, and Wang define the finite-field spike \(M_p^5\) over \(\operatorname{GF}(p)\): the tip \(e_1\), the vector \(e_2+\cdots+e_5\), and \(k\,e_1+e_m\) for \(m=2,\ldots,5\) and \(k\in\operatorname{GF}(p)\). It has rank 5 and \(4p+2\) elements, so the curve consists of genuine finite matroids at the admissible prime parameters. The same construction works verbatim over any finite field; this site also verified the member at \(q=4\).',
   'The full maximum over eligible element pairs is \(\frac{8}{7}\) for every member, so this is a horizontal solid curve: the value is attained on the nose by each finite member, not merely in a limit.',
   'The exact family value is proved in the cited paper. This site independently reconstructed every basis and recomputed the full maximum for the members over GF(2), GF(3), GF(4), GF(5), and GF(7).',
   'discovery',
   '[{"id":"p","label":"Mₚ⁵","points":[{"parameter":"p = 2","n":10,"rank":5,"num":8,"den":7,"field":2},{"parameter":"p = 3","n":14,"rank":5,"num":8,"den":7,"field":3},{"parameter":"p = 5","n":22,"rank":5,"num":8,"den":7,"field":5},{"parameter":"p = 7","n":30,"rank":5,"num":8,"den":7,"field":7},{"parameter":"p = 11","n":46,"rank":5,"num":8,"den":7,"field":11},{"parameter":"p = 13","n":54,"rank":5,"num":8,"den":7,"field":13},{"parameter":"p = 17","n":70,"rank":5,"num":8,"den":7,"field":17},{"parameter":"p = 19","n":78,"rank":5,"num":8,"den":7,"field":19},{"parameter":"p = 23","n":94,"rank":5,"num":8,"den":7,"field":23},{"parameter":"p = 29","n":118,"rank":5,"num":8,"den":7,"field":29}]}]');

INSERT INTO families
  (slug, status, name, short, claim, color, fields_json, parameter,
   formula_tex, size_rank_tex, supremum_num, supremum_den, supremum_kind,
   contributors, discovery_date, ai_disclosure, summary, construction,
   curve_explanation, proof_status, math_anchor, series_json)
VALUES
  ('uniform-self-sum-extensions', 'accepted', 'Uniform self-sum extensions', 'Uniform extensions', 'lower', '#176b72',
   '[]', 'integer \(r\ge 2\)',
   'R_{ef}(P_r) = \frac{4r^2}{3r^2+2r+1}',
   '|E(P_r)| = 4r+2, \qquad \operatorname{rk}(P_r) = 2r+1',
   4, 3, 'approached',
   'Alexander Divoux, Shouda Wang', 'August 2026',
   'Alexander Divoux and Shouda Wang used ChatGPT 5.6 Sol Ultra to assist the discovery of the original transversal-matroid family. Its reinterpretation as a double free-extension is due to humans. No public chat link is currently recorded.',
   'A finite matroid for every integer \(r\ge2\), with a certified distinguished-pair value tending to \(\frac{4}{3}\) from below.',
   'Start with two copies of \(U_{r,2r}\), take their direct sum, freely extend by \(e\), and then freely coextend by \(f\). The resulting matroid \(P_r\) has \(4r+2\) elements and rank \(2r+1\).',
   'Exact basis counts for the distinguished pair \((e,f)\) give \(\frac{4r^2}{3r^2+2r+1}\), so every plotted point is a certified lower bound, and the bounds approach \(\frac{4}{3}\) as \(r\to\infty\); no finite \(r\) attains it. Computational remark (this site): exact enumeration confirms \((e,f)\) is the unique maximizing pair for \(2\le r\le 5\), so the curve is exact on those members — \(P_5\) is the record for 22 elements.',
   'The adjacent-rank identity proves the displayed pair value and its limit; maximization over all pairs remains open for general \(r\).',
   'uniform-family',
   '[{"id":"r","label":"Pᵣ","points":[{"parameter":"r = 2","n":10,"rank":5,"num":16,"den":17},{"parameter":"r = 3","n":14,"rank":7,"num":18,"den":17},{"parameter":"r = 4","n":18,"rank":9,"num":64,"den":57},{"parameter":"r = 5","n":22,"rank":11,"num":50,"den":43},{"parameter":"r = 6","n":26,"rank":13,"num":144,"den":121},{"parameter":"r = 7","n":30,"rank":15,"num":98,"den":81},{"parameter":"r = 8","n":34,"rank":17,"num":256,"den":209},{"parameter":"r = 9","n":38,"rank":19,"num":162,"den":131},{"parameter":"r = 10","n":42,"rank":21,"num":400,"den":321},{"parameter":"r = 11","n":46,"rank":23,"num":242,"den":193},{"parameter":"r = 12","n":50,"rank":25,"num":576,"den":457},{"parameter":"r = 13","n":54,"rank":27,"num":338,"den":267},{"parameter":"r = 14","n":58,"rank":29,"num":784,"den":617},{"parameter":"r = 15","n":62,"rank":31,"num":450,"den":353},{"parameter":"r = 16","n":66,"rank":33,"num":1024,"den":801},{"parameter":"r = 17","n":70,"rank":35,"num":578,"den":451},{"parameter":"r = 18","n":74,"rank":37,"num":1296,"den":1009},{"parameter":"r = 19","n":78,"rank":39,"num":722,"den":561},{"parameter":"r = 20","n":82,"rank":41,"num":1600,"den":1241},{"parameter":"r = 21","n":86,"rank":43,"num":882,"den":683},{"parameter":"r = 22","n":90,"rank":45,"num":1936,"den":1497},{"parameter":"r = 23","n":94,"rank":47,"num":1058,"den":817},{"parameter":"r = 24","n":98,"rank":49,"num":2304,"den":1777},{"parameter":"r = 25","n":102,"rank":51,"num":1250,"den":963},{"parameter":"r = 26","n":106,"rank":53,"num":2704,"den":2081},{"parameter":"r = 27","n":110,"rank":55,"num":1458,"den":1121},{"parameter":"r = 28","n":114,"rank":57,"num":3136,"den":2409},{"parameter":"r = 29","n":118,"rank":59,"num":1682,"den":1291},{"parameter":"r = 30","n":122,"rank":61,"num":3600,"den":2761}]}]');

INSERT INTO families
  (slug, status, name, short, claim, color, fields_json, parameter,
   formula_tex, size_rank_tex, supremum_num, supremum_den, supremum_kind,
   contributors, discovery_date, ai_disclosure, summary, construction,
   curve_explanation, proof_status, math_anchor, series_json)
VALUES
  ('affine-self-sum-extensions', 'accepted', 'Affine-geometry self-sum extensions', 'Affine extensions', 'lower', '#6d4c93',
   '[]', 'integer \(d\ge2\) and prime power \(q\)',
   '\lim_{d\to\infty} R_{ef}(P_{d,q}) = \frac{4q^2}{3q^2+1}',
   '|E(P_{d,q})| = 2q^{d-1}+2, \qquad \operatorname{rk}(P_{d,q}) = 2d+1',
   4, 3, 'iterated limit',
   'Chris Eur', 'August 2026',
   'Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the family through the double-free construction and the common 2-design mechanism. A public chat link is not currently recorded.',
   'Affine-geometry self-sums give characteristic-indexed lower-bound curves whose iterated limit is \(\frac{4}{3}\).',
   'Let \(A=\operatorname{AG}(d-1,q)\), of rank \(d\) on \(q^{d-1}\) points, and form \(P_{d,q}=(A\oplus A)+e\times f\). The free extension and coextension may require passing to a finite extension field, but the result stays representable in characteristic \(p\) when \(q=p^a\).',
   'Möbius inversion on the affine-flat lattice gives every plotted value exactly. For fixed \(q\) they tend to \(4q^2/(3q^2+1)\) as \(d\to\infty\); for fixed \(d\) they tend to \(4d/(3d+1)\) as \(q\to\infty\). Either subsequent limit approaches \(\frac43\). The curves are dashed because they certify distinguished-pair lower bounds rather than the full maximum.',
   'Exact finite counts and both limits are proved on the mathematics page; maximization over every pair remains open.',
   'geometries',
   '[{"id":"q2","label":"q = 2","points":[{"parameter":"rank(A) = 3","n":10,"rank":7,"num":6,"den":7},{"parameter":"rank(A) = 4","n":18,"rank":9,"num":8,"den":7},{"parameter":"rank(A) = 5","n":34,"rank":11,"num":80,"den":67},{"parameter":"rank(A) = 6","n":66,"rank":13,"num":6,"den":5},{"parameter":"rank(A) = 8","n":258,"rank":17,"num":1168,"den":977}]},{"id":"q3","label":"q = 3","points":[{"parameter":"rank(A) = 3","n":20,"rank":7,"num":42,"den":37},{"parameter":"rank(A) = 4","n":56,"rank":9,"num":6,"den":5},{"parameter":"rank(A) = 5","n":164,"rank":11,"num":265,"den":218}]},{"id":"q5","label":"q = 5","points":[{"parameter":"rank(A) = 3","n":52,"rank":7,"num":150,"den":127},{"parameter":"rank(A) = 4","n":252,"rank":9,"num":1168,"den":959}]},{"id":"q7","label":"q = 7","points":[{"parameter":"rank(A) = 3","n":100,"rank":7,"num":306,"den":257},{"parameter":"rank(A) = 4","n":688,"rank":9,"num":104,"den":85}]}]');

INSERT INTO families
  (slug, status, name, short, claim, color, fields_json, parameter,
   formula_tex, size_rank_tex, supremum_num, supremum_den, supremum_kind,
   contributors, discovery_date, ai_disclosure, summary, construction,
   curve_explanation, proof_status, math_anchor, series_json)
VALUES
  ('projective-self-sum-extensions', 'accepted', 'Projective-geometry self-sum extensions', 'Projective extensions', 'lower', '#b5652a',
   '[]', 'integer \(d\ge2\) and prime power \(q\)',
   '\lim_{d\to\infty} R_{ef}(P_{d,q}) = \frac{4q^2}{3q^2+1}',
   '|E(P_{d,q})| = 2\tfrac{q^d-1}{q-1}+2, \qquad \operatorname{rk}(P_{d,q}) = 2d+1',
   4, 3, 'iterated limit',
   'Chris Eur', 'August 2026',
   'Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the family through the double-free construction and the common 2-design mechanism. A public chat link is not currently recorded.',
   'Projective-geometry self-sums give characteristic-indexed lower-bound curves with the same two limiting regimes as the affine geometries.',
   'Let \(G=\operatorname{PG}(d-1,q)\), of rank \(d\) on \((q^d-1)/(q-1)\) points, and form \(P_{d,q}=(G\oplus G)+e\times f\). A field extension may be necessary to carry out the free extension and coextension.',
   'Möbius inversion on the projective-flat lattice gives every plotted value exactly; for fixed \(q\) the values tend to \(4q^2/(3q^2+1)\), for fixed \(d\) to \(4d/(3d+1)\), and a subsequent limit approaches \(\frac43\).',
   'The displayed pair is certified exactly; full maximization remains open.',
   'geometries',
   '[{"id":"q2","label":"q = 2","points":[{"parameter":"rank(PG) = 3","n":16,"rank":7,"num":10,"den":9},{"parameter":"rank(PG) = 4","n":32,"rank":9,"num":128,"den":109},{"parameter":"rank(PG) = 5","n":64,"rank":11,"num":70,"den":59},{"parameter":"rank(PG) = 6","n":128,"rank":13,"num":297,"den":250},{"parameter":"rank(PG) = 8","n":512,"rank":17,"num":7456,"den":6275}]},{"id":"q3","label":"q = 3","points":[{"parameter":"rank(PG) = 3","n":28,"rank":7,"num":36,"den":31},{"parameter":"rank(PG) = 4","n":82,"rank":9,"num":256,"den":213},{"parameter":"rank(PG) = 5","n":244,"rank":11,"num":1640,"den":1351},{"parameter":"rank(PG) = 6","n":730,"rank":13,"num":12528,"den":10261}]},{"id":"q5","label":"q = 5","points":[{"parameter":"rank(PG) = 3","n":64,"rank":7,"num":32,"den":27},{"parameter":"rank(PG) = 4","n":314,"rank":9,"num":2944,"den":2417},{"parameter":"rank(PG) = 5","n":1564,"rank":11,"num":3200,"den":2593}]},{"id":"q7","label":"q = 7","points":[{"parameter":"rank(PG) = 3","n":116,"rank":7,"num":180,"den":151},{"parameter":"rank(PG) = 4","n":802,"rank":9,"num":7296,"den":5963}]}]');

INSERT INTO families
  (slug, status, name, short, claim, color, fields_json, parameter,
   formula_tex, size_rank_tex, supremum_num, supremum_den, supremum_kind,
   contributors, discovery_date, ai_disclosure, summary, construction,
   curve_explanation, proof_status, math_anchor, series_json)
VALUES
  ('steiner-system-self-sum-extensions', 'accepted', 'Steiner-system sparse-paving extensions', 'Steiner extensions', 'lower', '#34745b',
   '[]', 'Steiner systems \(S(r-1,r,n)\)',
   'R_{ef}(P_{r,n}) = \frac{4r(n-r+1)}{(3r+1)(n-r)+4r+2}',
   '|E(P_{r,n})| = 2n+2, \qquad \operatorname{rk}(P_{r,n}) = 2r+1',
   4, 3, 'iterated limit',
   'Chris Eur', 'August 2026',
   'Chris Eur used ChatGPT 5.6 Sol Max on Codex as a mathematical exploration and formula-checking aid while identifying the family, beginning with Steiner triples. A public chat link is not currently recorded.',
   'Sparse-paving matroids from Steiner systems give nonuniform 2-design bases and distinguished-pair values approaching \(\frac43\).',
   'Take the blocks of a Steiner system \(S(r-1,r,n)\) as the circuit-hyperplanes of a rank-\(r\) sparse-paving matroid \(M_{r,n}\), then form \(P_{r,n}=(M_{r,n}\oplus M_{r,n})+e\times f\). The plotted series use Steiner triple and quadruple systems, whose admissible orders are explicit.',
   'For fixed \(r\), the formula tends to \(4r/(3r+1)\) as \(n\to\infty\); those limits tend to \(\frac43\) as \(r\to\infty\). Keevash''s design-existence theorem supplies the general fixed-rank families at all sufficiently large admissible orders.',
   'The adjacent-rank counts prove the displayed pair value exactly; full maximization remains open.',
   'steiner',
   '[{"id":"s23","label":"S(2,3,n)","points":[{"parameter":"n = 7","n":16,"rank":7,"num":10,"den":9},{"parameter":"n = 9","n":20,"rank":7,"num":42,"den":37},{"parameter":"n = 13","n":28,"rank":7,"num":22,"den":19},{"parameter":"n = 15","n":32,"rank":7,"num":78,"den":67},{"parameter":"n = 19","n":40,"rank":7,"num":34,"den":29},{"parameter":"n = 21","n":44,"rank":7,"num":114,"den":97},{"parameter":"n = 25","n":52,"rank":7,"num":46,"den":39},{"parameter":"n = 27","n":56,"rank":7,"num":150,"den":127},{"parameter":"n = 31","n":64,"rank":7,"num":58,"den":49},{"parameter":"n = 33","n":68,"rank":7,"num":186,"den":157},{"parameter":"n = 37","n":76,"rank":7,"num":70,"den":59},{"parameter":"n = 39","n":80,"rank":7,"num":222,"den":187},{"parameter":"n = 43","n":88,"rank":7,"num":82,"den":69},{"parameter":"n = 45","n":92,"rank":7,"num":258,"den":217},{"parameter":"n = 49","n":100,"rank":7,"num":94,"den":79},{"parameter":"n = 51","n":104,"rank":7,"num":294,"den":247},{"parameter":"n = 55","n":112,"rank":7,"num":106,"den":89},{"parameter":"n = 57","n":116,"rank":7,"num":330,"den":277},{"parameter":"n = 61","n":124,"rank":7,"num":118,"den":99},{"parameter":"n = 63","n":128,"rank":7,"num":366,"den":307},{"parameter":"n = 67","n":136,"rank":7,"num":130,"den":109},{"parameter":"n = 69","n":140,"rank":7,"num":402,"den":337},{"parameter":"n = 73","n":148,"rank":7,"num":142,"den":119}]},{"id":"s34","label":"S(3,4,n)","points":[{"parameter":"n = 8","n":18,"rank":9,"num":8,"den":7},{"parameter":"n = 10","n":22,"rank":9,"num":7,"den":6},{"parameter":"n = 14","n":30,"rank":9,"num":44,"den":37},{"parameter":"n = 16","n":34,"rank":9,"num":104,"den":87},{"parameter":"n = 20","n":42,"rank":9,"num":136,"den":113},{"parameter":"n = 22","n":46,"rank":9,"num":76,"den":63},{"parameter":"n = 26","n":54,"rank":9,"num":23,"den":19},{"parameter":"n = 28","n":58,"rank":9,"num":40,"den":33},{"parameter":"n = 32","n":66,"rank":9,"num":232,"den":191},{"parameter":"n = 34","n":70,"rank":9,"num":62,"den":51},{"parameter":"n = 38","n":78,"rank":9,"num":28,"den":23},{"parameter":"n = 40","n":82,"rank":9,"num":296,"den":243},{"parameter":"n = 44","n":90,"rank":9,"num":328,"den":269},{"parameter":"n = 46","n":94,"rank":9,"num":172,"den":141},{"parameter":"n = 50","n":102,"rank":9,"num":94,"den":77},{"parameter":"n = 52","n":106,"rank":9,"num":392,"den":321},{"parameter":"n = 56","n":114,"rank":9,"num":424,"den":347},{"parameter":"n = 58","n":118,"rank":9,"num":11,"den":9},{"parameter":"n = 62","n":126,"rank":9,"num":236,"den":193},{"parameter":"n = 64","n":130,"rank":9,"num":488,"den":399},{"parameter":"n = 68","n":138,"rank":9,"num":104,"den":85},{"parameter":"n = 70","n":142,"rank":9,"num":268,"den":219},{"parameter":"n = 74","n":150,"rank":9,"num":71,"den":58}]}]');

