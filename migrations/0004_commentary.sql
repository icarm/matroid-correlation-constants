-- Editable per-matroid commentary: one current text per entry, kept as an
-- append-only log of edits; the matroid points at its latest entry via
-- current_comment_id. Empty content represents a "clear".

CREATE TABLE IF NOT EXISTS commentary_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  matroid_id INTEGER NOT NULL REFERENCES matroids(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,            -- '' represents a "clear" edit
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_commentary_log_matroid ON commentary_log(matroid_id, id);

ALTER TABLE matroids ADD COLUMN current_comment_id INTEGER REFERENCES commentary_log(id);
