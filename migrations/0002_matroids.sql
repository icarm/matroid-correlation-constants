-- Verified record matroids, append-only: when a submission's correlation
-- constant strictly exceeds the previous record for its ground-set size n,
-- a new row is added. Superseded records are kept as history; the current
-- record for n is its most recent row (records only ever increase, so the
-- max id per n is also the max alpha).

CREATE TABLE IF NOT EXISTS matroids (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  n INTEGER NOT NULL,               -- ground-set size; elements are 0..n-1
  rank INTEGER NOT NULL,
  num_bases INTEGER NOT NULL,
  alpha_num INTEGER NOT NULL,       -- correlation constant, reduced fraction
  alpha_den INTEGER NOT NULL,
  alpha_value REAL NOT NULL,        -- decimal approximation for display/plots
  max_pairs TEXT NOT NULL,          -- JSON list of maximizing pairs [i, j]
  max_counts TEXT,                  -- JSON 2x2 basis counts at the first
                                    -- maximizing pair; NULL when no eligible pair
  representation_type TEXT NOT NULL,-- 'matrix' | 'bases' | 'circuits' | 'hyperplanes'
  representation TEXT NOT NULL,     -- normalized JSON of the submitted description
  field TEXT,                       -- 'Q' or the prime p, for matrix submissions
  bases TEXT,                       -- canonical JSON list of bases (sorted);
                                    -- NULL when too large to store
  bases_hash TEXT NOT NULL,         -- sha256 of the canonical bases JSON
  provenance TEXT,                  -- optional discoverers / date / AI disclosure
  submitter_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_matroids_n_alpha ON matroids(n, alpha_num, alpha_den);
CREATE INDEX IF NOT EXISTS idx_matroids_alpha ON matroids(alpha_value DESC);
