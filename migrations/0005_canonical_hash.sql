-- The canonical matroid hash scheme changed when verification became
-- streaming: bases_hash is now a chunked SHA-256 over the basis-mask stream
-- in ascending numeric order (little-endian 4-byte masks in 2^16-mask
-- blocks; the final digest hashes the concatenated block digests), replacing
-- the earlier JSON-or-flat-binary schemes. Rows 1-7 predate the change;
-- their new hashes were recomputed from their stored representations, each
-- re-verified against its stored constant and basis count first.

UPDATE matroids SET bases_hash = '9584117e622db03e2e7a892f4aaa45f40ab91ae81fa3d08fbcb9734796ebfc59' WHERE id = 1;  -- n=10, α=8/7, 136 bases
UPDATE matroids SET bases_hash = '5a62e54d08096f5f4a24066358d7fa42136483c5e8fcabfa8c4cd92e1353a6af' WHERE id = 2;  -- n=14, α=8/7, 891 bases
UPDATE matroids SET bases_hash = '852a3810ab9ce3516c42ebc1bee1438fcabd2398021d0aba7a2d21790bcfc5a5' WHERE id = 3;  -- n=12, α=100/81, 684 bases
UPDATE matroids SET bases_hash = 'a03c81839ce29c6e89ac4013011ec7dfab7d63256da6739ed9ccc9c87d7cbc6b' WHERE id = 4;  -- n=22, α=8/7, 9625 bases
UPDATE matroids SET bases_hash = '43c4e0ff3c379c939dd517c907c61850aef8e5a5debcb9a6cc12e88fdfec892e' WHERE id = 5;  -- n=18, α=8/7, 3392 bases
UPDATE matroids SET bases_hash = '0de07f8f24a3cdb95295b632ac06792b46a8439ef65f2f88418882ced8e8b6ea' WHERE id = 6;  -- n=26, α=280043/243256, 1518400 bases
UPDATE matroids SET bases_hash = 'de2c563cfc767736ff6ae1ca0ad76e59fa8fe680a8eaa50d07ea561b2de34056' WHERE id = 7;  -- n=30, α=8/7, 46991 bases
