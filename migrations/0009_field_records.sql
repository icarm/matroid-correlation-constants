-- Field-keyed records replace per-ground-set-size records (decided with
-- Chris Eur, 2026-08-07). The record book tracks exactly two things:
--
--   * the best verified alpha over each of GF(2), GF(3), GF(4), GF(5),
--     GF(7) — a "field record", held until strictly beaten by a matroid
--     verified over that field (a matrix over GF(2) also contends for
--     GF(4), the one subfield pair in the menu);
--   * every concrete matroid reaching alpha >= 4/3, with any description
--     ("the 4/3 club" — membership is permanent, not a record to beat).
--
-- record_titles is append-only, like matroids: one row per title taken.
-- The current record for a field is its row with the largest id; club
-- rows (field IS NULL) never expire. Matroid rows that hold no current
-- title remain as history.

CREATE TABLE IF NOT EXISTS record_titles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  matroid_id INTEGER NOT NULL REFERENCES matroids(id),
  field INTEGER,                    -- 2, 3, 4, 5, or 7; NULL = the 4/3 club
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_record_titles_field ON record_titles(field, id);
-- A matroid joins the club at most once; its alpha never changes, so it can
-- also take a given field record at most once.
CREATE UNIQUE INDEX IF NOT EXISTS idx_record_titles_club
  ON record_titles(matroid_id) WHERE field IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_record_titles_matroid_field
  ON record_titles(matroid_id, field) WHERE field IS NOT NULL;

-- Two different matroids may now legitimately share (n, alpha): e.g. the
-- GF(2) and GF(4) records could tie. Duplicate-matroid detection is by
-- bases_hash instead.
DROP INDEX IF EXISTS idx_matroids_n_alpha;
CREATE INDEX IF NOT EXISTS idx_matroids_hash ON matroids(bases_hash);

-- Backfill from the production rows, in chronological order per field so
-- max(id) lands on the right holder. Each insert is guarded on the exact
-- row it targets (id, alpha, field), so a database without that row — a
-- fresh local dev DB — simply gets no title and stays consistent.
--
--   GF(2): #1 HSW spike M_2^5 (8/7), unbeaten.
--   GF(3): #2 spike M_3^5 (8/7), then #3 ternary rank-6 benchmark (100/81).
--   GF(4): #5 spike M_4^5 (8/7), unbeaten.
--   GF(5): #4 spike M_5^5 (8/7), then #9 n=22 rank-9 (4664/4007).
--   GF(7): #6 n=26 rank-9 (280043/243256); spike #7 never beat it.
INSERT INTO record_titles (matroid_id, field)
  SELECT 1, 2 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 1 AND alpha_num = 8 AND alpha_den = 7 AND field = '2');
INSERT INTO record_titles (matroid_id, field)
  SELECT 2, 3 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 2 AND alpha_num = 8 AND alpha_den = 7 AND field = '3');
INSERT INTO record_titles (matroid_id, field)
  SELECT 3, 3 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 3 AND alpha_num = 100 AND alpha_den = 81 AND field = '3');
INSERT INTO record_titles (matroid_id, field)
  SELECT 5, 4 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 5 AND alpha_num = 8 AND alpha_den = 7 AND field = '4');
INSERT INTO record_titles (matroid_id, field)
  SELECT 4, 5 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 4 AND alpha_num = 8 AND alpha_den = 7 AND field = '5');
INSERT INTO record_titles (matroid_id, field)
  SELECT 9, 5 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 9 AND alpha_num = 4664 AND alpha_den = 4007 AND field = '5');
INSERT INTO record_titles (matroid_id, field)
  SELECT 6, 7 WHERE EXISTS (SELECT 1 FROM matroids WHERE id = 6 AND alpha_num = 280043 AND alpha_den = 243256 AND field = '7');
