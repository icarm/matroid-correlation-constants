-- This proposal was accepted accidentally in production. Reject exactly
-- that accepted row, remove its acceptance-only chart color, and leave the
-- original reviewer attribution in place.
UPDATE families
   SET status = 'rejected',
       color = NULL,
       reviewed_at = CURRENT_TIMESTAMP,
       review_note = 'Rejected; previous acceptance was accidental.'
 WHERE slug = 'punctured-projective-block-affine-fibre-matroids'
   AND status = 'accepted';
