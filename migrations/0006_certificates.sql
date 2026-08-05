-- Representability certificates. When a submission exactly ties the current
-- record matroid (identical bases, by canonical hash) and is a matrix over a
-- field, while the record row carries no verified field, the matrix is
-- attached to the existing row instead of being discarded: the row keeps its
-- original description and gains a field badge.

ALTER TABLE matroids ADD COLUMN cert_field TEXT;   -- 'Q' or the field order
ALTER TABLE matroids ADD COLUMN cert_matrix TEXT;  -- normalized JSON rows
