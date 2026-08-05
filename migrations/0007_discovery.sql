-- Structured discovery metadata, following the draft site's submission
-- schema: discovery is distinct from submission, AI use is disclosed as data
-- rather than prose, and every row records which verifier version produced
-- it. The free-text provenance column stays as general notes.

ALTER TABLE matroids ADD COLUMN name TEXT;             -- display name
ALTER TABLE matroids ADD COLUMN discoverers TEXT;
ALTER TABLE matroids ADD COLUMN discovery_date TEXT;   -- YYYY-MM or YYYY-MM-DD
ALTER TABLE matroids ADD COLUMN ai_used INTEGER;       -- boolean; NULL = undisclosed
ALTER TABLE matroids ADD COLUMN ai_model TEXT;
ALTER TABLE matroids ADD COLUMN ai_role TEXT;
ALTER TABLE matroids ADD COLUMN ai_chat_url TEXT;
ALTER TABLE matroids ADD COLUMN citation TEXT;
ALTER TABLE matroids ADD COLUMN verifier_version TEXT;

-- Backfill for the rows submitted before these fields existed, from their
-- provenance notes (which were written from the discovery record). max_pairs
-- moves to the per-pair-counts shape [{i, j, counts}], recomputed from each
-- row's stored representation and checked against its stored constant.

UPDATE matroids SET
  name = 'HSW finite-field spike M_2^5',
  discoverers = 'June Huh, Benjamin Schröter, Botong Wang',
  discovery_date = '2018-06',
  ai_used = 0,
  citation = 'arXiv:1806.02675, Definition 19 (JEMS 24 (2022), 1335–1351)'
  WHERE id = 1;
UPDATE matroids SET
  name = 'HSW finite-field spike M_3^5',
  discoverers = 'June Huh, Benjamin Schröter, Botong Wang',
  discovery_date = '2018-06',
  ai_used = 0,
  citation = 'arXiv:1806.02675, Definition 19 (JEMS 24 (2022), 1335–1351)'
  WHERE id = 2;
UPDATE matroids SET
  name = 'Ternary rank-6 benchmark',
  discoverers = 'Chris Eur and David Renshaw; independently June Huh',
  discovery_date = '2026-08',
  ai_used = 1,
  ai_model = 'AlphaEvolve; ChatGPT 5.5 Pro',
  ai_role = 'Found in a computer search using AlphaEvolve (Eur–Renshaw) and independently through the study of Mathieu groups with ChatGPT 5.5 Pro assisting (Huh).'
  WHERE id = 3;
UPDATE matroids SET
  name = 'HSW finite-field spike M_5^5',
  discoverers = 'June Huh, Benjamin Schröter, Botong Wang',
  discovery_date = '2018-06',
  ai_used = 0,
  citation = 'arXiv:1806.02675, Definition 19 (JEMS 24 (2022), 1335–1351)'
  WHERE id = 4;
UPDATE matroids SET
  name = 'HSW spike construction at q = 4',
  discoverers = 'Construction: Huh–Schröter–Wang; instantiated over GF(4) for this site',
  discovery_date = '2026-08',
  ai_used = 1,
  ai_model = 'Claude Fable 5 (via Claude Code)',
  ai_role = 'Assembled and verified the GF(4) instantiation of the spike construction.',
  citation = 'arXiv:1806.02675, Definition 19'
  WHERE id = 5;
UPDATE matroids SET
  name = 'Double-extension sample over GF(7)',
  discoverers = 'Chris Eur',
  discovery_date = '2026-08',
  ai_used = 1,
  ai_model = 'ChatGPT 5.6 Sol Ultra',
  ai_role = 'Found by prompting it to look at the website and beat one of the listed challenges.'
  WHERE id = 6;
UPDATE matroids SET
  name = 'HSW finite-field spike M_7^5',
  discoverers = 'June Huh, Benjamin Schröter, Botong Wang',
  discovery_date = '2018-06',
  ai_used = 0,
  citation = 'arXiv:1806.02675, Definition 19 (JEMS 24 (2022), 1335–1351)'
  WHERE id = 7;
UPDATE matroids SET
  name = 'Uniform self-sum extension P_5',
  discoverers = 'Family: Alexander Divoux and Shouda Wang; explicit realization for this site',
  discovery_date = '2026-08',
  ai_used = 1,
  ai_model = 'ChatGPT 5.6 Sol Ultra; Claude Fable 5 (via Claude Code)',
  ai_role = 'ChatGPT 5.6 Sol Ultra assisted the discovery of the family; Claude Fable 5 constructed and certified the explicit GF(999983) realization.'
  WHERE id = 8;

UPDATE matroids SET max_pairs = '[{"i":0,"j":1,"counts":{"containBoth":32,"avoidBoth":32,"onlyI":16,"onlyJ":56}}]', verifier_version = '2.0.0' WHERE id = 1;
UPDATE matroids SET max_pairs = '[{"i":0,"j":1,"counts":{"containBoth":108,"avoidBoth":324,"onlyI":81,"onlyJ":378}}]', verifier_version = '2.0.0' WHERE id = 2;
UPDATE matroids SET max_pairs = '[{"i":5,"j":10,"counts":{"containBoth":180,"avoidBoth":180,"onlyI":162,"onlyJ":162}}]', verifier_version = '2.0.0' WHERE id = 3;
UPDATE matroids SET max_pairs = '[{"i":0,"j":1,"counts":{"containBoth":500,"avoidBoth":5000,"onlyI":625,"onlyJ":3500}}]', verifier_version = '2.0.0' WHERE id = 4;
UPDATE matroids SET max_pairs = '[{"i":0,"j":1,"counts":{"containBoth":256,"avoidBoth":1536,"onlyI":256,"onlyJ":1344}}]', verifier_version = '2.0.0' WHERE id = 5;
UPDATE matroids SET max_pairs = '[{"i":24,"j":25,"counts":{"containBoth":174086,"avoidBoth":654401,"onlyI":486512,"onlyJ":203401}}]', verifier_version = '2.0.0' WHERE id = 6;
UPDATE matroids SET max_pairs = '[{"i":0,"j":1,"counts":{"containBoth":1372,"avoidBoth":28812,"onlyI":2401,"onlyJ":14406}}]', verifier_version = '2.0.0' WHERE id = 7;
UPDATE matroids SET max_pairs = '[{"i":20,"j":21,"counts":{"containBoth":105840,"avoidBoth":105840,"onlyI":151704,"onlyJ":63504}}]', verifier_version = '2.0.0' WHERE id = 8;
