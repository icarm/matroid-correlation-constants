# Recommendations for the ICARM Matroid Database

This document reviews the public state of
[matroids.icarm.cloud](https://matroids.icarm.cloud/) and the accompanying
[matroid-database-client](https://github.com/icarm/matroid-database-client) as
of July 2026. It is written from the perspective of a researcher who wants to
perform reproducible computations and statistically meaningful sampling from
the enumerations.

The release is already an important contribution. In particular, making the
rank-$5$, $10$-element enumeration available turns a previously inaccessible
collection into a potentially transformative research resource. The
recommendations below are intended to make that resource scientifically
self-describing, verifiable, and easier to use without requiring every user to
read the website and client source code.

## Executive summary

The current website does several things well:

- It gives a simple index of the available $(n,r)$ enumerations.
- Each enumeration page states its number of records, chunk count, compressed
  size, and basis-string length.
- A machine-readable manifest gives chunk URLs and global index ranges.
- Data files are publicly downloadable without an account.
- Both the website and the Rust client are open source.
- The client can decode the compact data into ordinary `0`/`*` strings.
- The website supplies an ICARM/NSF acknowledgment statement.

The most important shortfalls are not defects in the enumerations themselves.
They are missing contracts around the data:

1. The website does not precisely state what one record represents. In
   particular, it should explicitly say whether the collection is complete,
   isomorph-free, labeled or unlabeled, and whether loops, coloops, parallel
   elements, and non-simple matroids are included.
2. The website and client do not document the basis encoding sufficiently.
   The alphabet and record length are visible, but the order of the
   $r$-subsets and the meanings of `0` and `*` are not part of a published
   format specification.
3. The rank-$5$, $10$-element enumeration has no visible scientific
   provenance: no description of the enumeration method, verification,
   authorship, release note, paper, or recommended dataset citation.
4. Dataset releases are not visibly versioned or immutable, and the current
   manifests do not contain cryptographic chunk hashes.
5. The client offers sequential interval access, not efficient random access.
   An index in the middle of a $100$-million-record chunk requires sequential
   decoding from the beginning of that chunk.
6. The client README is much too short for a format of this scale. It omits
   installation instructions, resource behavior, the sampling implications of
   record order, integrity checking, and the precise output contract.
7. The website asks for acknowledgment but does not state a data license.

The highest-priority revisions should therefore be:

| Priority | Recommended revision |
|---|---|
| P0 | Publish a precise scope, completeness, and isomorphism statement for every enumeration. |
| P0 | Publish a versioned specification of the reverse-lexicographic basis encoding and the `.sz.xz` format. |
| P0 | Add dataset authorship, provenance, verification, citation, and license information. |
| P0 | Make releases immutable and add SHA-256 hashes to manifests. |
| P1 | Expand the client documentation and provide prebuilt versioned binaries. |
| P1 | Add reproducible uniform-index sampling and make its cost and probability measure explicit. |
| P1 | Add smaller independently decodable blocks or decoder checkpoints for practical random access. |
| P2 | Add bindings or examples for Python, Julia/OSCAR, SageMath, and other common systems. |
| P2 | Publish aggregate structural statistics where they can be collected economically. |

## 1. State exactly what has been enumerated

### Current shortfall

An enumeration page currently says, for example, “Matroids on 10 elements of
rank 5” and gives a record count. That leaves several scientifically important
questions unanswered:

- Is there exactly one representative of each isomorphism class?
- Is the enumeration proved or computationally verified to be complete?
- What is the ground-set convention?
- Are loops and coloops included?
- Are parallel and series elements included?
- Are simple, paving, representable, or other restrictions imposed?
- Are records matroids, representations of matroids, or labeled copies?
- Does the rank-$6$ collection consist of explicitly stored duals of the
  rank-$4$ collection, or was it generated independently?

The rank-$4$, $10$-element count agrees with the known complete isomorph-free
enumeration of Matsumoto, Moriyama, Imai, and Bremner. A new user should not
have to infer that connection from the count. The rank-$5$ enumeration is new
enough that an explicit statement is even more important.

### Recommended revision

Every enumeration should have a human-readable and machine-readable scope
statement such as:

> This release contains exactly one representative of every matroid
> isomorphism class of rank $5$ on a $10$-element ground set. Loops, coloops,
> parallel elements, series elements, disconnected matroids, and non-simple
> matroids are included. Completeness was established by [method/reference].

If any part of that statement is not applicable, the page should say exactly
what is known instead. A status badge such as `complete`, `candidate complete`,
`partial`, or `independently verified` would be helpful, provided its meaning
is formally defined.

Suggested manifest fields include:

```json
{
  "recordSemantics": "one representative per matroid isomorphism class",
  "completeness": "complete",
  "groundSet": "{0,...,n-1}",
  "includesLoops": true,
  "includesColoops": true,
  "includesParallelElements": true,
  "includesDisconnectedMatroids": true
}
```

## 2. Document scientific provenance and verification

### Current shortfall

The site currently identifies ICARM as the maintainer, but it does not identify
the authors of each enumeration or explain how it was produced. For the new
$n=10$, $r=5$ result, the record count itself is a substantial mathematical
result. Researchers need to know:

- who performed the enumeration;
- which program, algorithm, and source-code revision produced it;
- which computational resources were used;
- how isomorph rejection was performed;
- what independent checks were applied;
- whether duality or known lower-rank counts were used as validation;
- whether the result is described in a paper, preprint, technical report, or
  archived computational certificate.

### Recommended revision

Add a provenance block to each enumeration page and manifest. It should
include:

- enumeration authors and contributors;
- software repository and exact commit;
- algorithm or paper reference;
- generation and validation dates;
- a concise completeness/verification statement;
- known cross-checks;
- the recommended citation;
- a DOI or archival identifier when one becomes available.

The website can distinguish between:

1. citation of the mathematical enumeration;
2. citation of the hosted dataset release; and
3. acknowledgment of ICARM and NSF support.

These are complementary and should not be collapsed into a single
acknowledgment sentence.

## 3. Publish a normative basis-encoding specification

### Current shortfall

The client emits strings of length $\binom nr$ using `0` and `*`, but its
public README does not define:

- whether `*` denotes a basis or a nonbasis;
- the ordering of the $r$-subsets;
- whether element labels begin at zero or one;
- the relation to the Matsumoto, SageMath, and polyDB RevLex conventions;
- the convention used under matroid duality.

These details are essential. Reversing or otherwise permuting the subset order
still produces a syntactically valid string but describes a different labeled
matroid to downstream software.

### Recommended revision

State explicitly that a decoded record has one character for each $r$-subset,
that `*` means basis, and that `0` means nonbasis. Define the subset order
algorithmically and include a small example.

For example, if the intended convention is the standard polyDB-compatible
reverse-lexicographic/colex order, the $2$-subsets of
$\{0,1,2,3\}$ occur as

$$
\{0,1\},\{0,2\},\{1,2\},\{0,3\},\{1,3\},\{2,3\}.
$$

The specification should give enough pseudocode that two independent
implementations necessarily produce the same order. It should also provide
several golden test records, including a uniform matroid, a matroid with a
loop or coloop, the Fano matroid, and a dual pair.

The manifest should name and version the encoding, for example:

```json
{
  "recordEncoding": {
    "name": "revlex-bases",
    "version": 1,
    "basisCharacter": "*",
    "nonbasisCharacter": "0",
    "elementLabels": "0-based"
  }
}
```

## 4. Publish a normative `.sz.xz` format specification

### Current shortfall

At present, the most complete specification of `.sz.xz` is the Rust source.
Reading the implementation reveals that the decoded `.sz` stream contains a
little-endian line-length/count header, a literal first line, and
sentinel-terminated lists of changed positions for subsequent lines. Bit
order, sentinel rules, and error conditions should not have to be
reverse-engineered from code.

### Recommended revision

Publish a short format document defining:

- magic bytes and a format-version field;
- integer widths and endianness;
- header layout;
- first-record representation;
- number of bits per changed position;
- bit order;
- sentinel value;
- allowed character values;
- required record count and termination behavior;
- outer compression format and supported xz options;
- validation and corruption behavior.

The current format appears not to have magic bytes or an explicit version.
Future files should include both. Existing files can be documented as version
`0` without being rewritten.

Provide a tiny test file containing perhaps ten records, together with its
expected decoded output and SHA-256 hash. That fixture would make independent
Julia, Python, SageMath, and C/C++ decoders much safer to implement.

## 5. Version releases and provide cryptographic integrity

### Current shortfall

The public manifest identifies chunks by global index range and supplies their
sizes and upload timestamps. It does not currently supply a cryptographic
hash. The client verifies SHA-256 for a legacy manifest format but sets no
expected hash when reading the current version-2 manifests.

The website source also allows manifests to be regenerated. Without an
immutable release identifier, a global index such as `n10r05:123456789` is not
necessarily a permanent scientific identifier.

### Recommended revision

Treat an enumeration publication as an immutable, versioned dataset release:

```text
n10r05-v1
```

For each release:

- publish a SHA-256 hash for every compressed chunk;
- publish a SHA-256 hash for the canonical manifest;
- retain old manifests and files permanently;
- use new version identifiers for any correction or reordering;
- publish a changelog explaining every replacement;
- make `(release ID, global index)` a stable record identifier.

The client should verify hashes by default and offer an explicit
`--no-verify` escape hatch rather than silently omitting verification.

Because JSON implementations differ in their treatment of large integers,
counts and indexes should consistently be serialized as decimal strings, even
while current counts remain below JavaScript's safe-integer limit.

## 6. Make access costs and limitations visible

### Current shortfall

The data are extremely well compressed. This can make an enumeration look
much cheaper to process than it is:

- the rank-$4$, $10$-element archive is only about $657$ MiB compressed but
  expands to roughly $1.03$ TB of newline-delimited basis strings;
- the rank-$5$, $10$-element archive is about $414$ GiB compressed but would
  expand to roughly $815$ TB of newline-delimited strings.

The client downloads a complete compressed chunk into memory and then
sequentially decodes it. `--start` and `--end` restrict emitted records, but
they do not provide record-level seeking within a chunk. To obtain a record
near the end of a $100$-million-record chunk, the decoder must reconstruct all
preceding records in that chunk.

That behavior is reasonable for a compact delta format, but it is currently
not explained to users. It particularly affects statistical sampling:
requesting a few scattered global indexes can require decoding billions of
unwanted records.

### Recommended revision

Each enumeration page should report:

- compressed size;
- decoded record count;
- estimated decoded text size;
- typical compressed chunk size;
- records per chunk;
- whether access is sequential or seekable;
- approximate memory behavior of the official client.

The client README and `--help` output should clearly explain that global index
intervals are sequential within a chunk.

## 7. Add practical random access or checkpointing

### Current shortfall

The current combination of $100$-million-record chunks, xz compression, and
delta coding is optimized for full sequential scans. It is poorly matched to
queries such as:

- retrieve record number $k$;
- take a seeded uniform sample of $10{,}000$ isomorphism classes;
- inspect a small random sample from each part of the enumeration;
- resume a partial statistical experiment near a particular record.

HTTP byte-range support alone cannot solve this because the delta chain
requires prior decoded state.

### Recommended revision

Any of the following would materially improve access:

1. Store smaller independently decodable chunks, perhaps $10^5$ to $10^6$
   records each.
2. Retain large downloadable objects but make each object a concatenation of
   independently compressed blocks with a sidecar byte-offset index.
3. Add periodic restart records and xz seek points.
4. Publish a second access-oriented representation while retaining the current
   archival representation.

A sidecar index could map every millionth global record to:

```text
(object, compressed block offset, record number, literal restart record)
```

The correct block size should be chosen from actual benchmarks, but the design
goal should be that retrieving one random record requires decoding at most
about $10^5$--$10^6$ records rather than $10^8$.

## 8. Add a statistically explicit sampling command

### Current shortfall

The client accepts a contiguous global interval but does not provide a
sampling operation. Researchers may consequently take the first $N$ records,
even though enumeration order is likely highly structured. That sample is
generally not representative of the isomorphism-class population.

### Recommended revision

Add a command such as:

```bash
matroid-db sample 10 5 \
  --count 10000 \
  --seed 20260730 \
  --without-replacement \
  --output sample.revlex
```

The command should:

- sample global indexes uniformly from the complete record range;
- state that the probability measure is uniform over stored records;
- support sampling with or without replacement;
- save the seed, release ID, and selected indexes;
- group selected indexes by chunk or restart block for efficient decoding;
- emit a machine-readable sample manifest;
- never describe a prefix sample as random.

If efficient uniform sampling cannot yet be supported, the documentation
should say so plainly and describe the statistical limitations of the
available alternatives.

The distinction between the following probability measures should be
prominent:

- uniform over stored isomorphism classes;
- uniform over labeled matroids;
- uniform over matrix or projective representations;
- uniform over finite-field point configurations.

These measures can produce very different empirical distributions.

## 9. Expand the client into a documented consumer tool

### Current shortfall

The current README contains one short invocation. It does not explain the
file format, installation, output, caching, failures, or resource use. The
repository contains useful decoder and rechunking code, but a new user has to
read Rust source to discover most behavior.

### Recommended revision

Document and, where appropriate, implement commands along these lines:

```text
matroid-db list
matroid-db info 10 5
matroid-db iterate 10 5 --start K --end L
matroid-db get 10 5 --index K
matroid-db sample 10 5 --count N --seed S
matroid-db download 10 5 --verify
matroid-db verify PATH
```

The documentation should include:

- installation from source;
- prebuilt, checksummed release binaries;
- supported operating systems;
- exact stdout/stderr contracts;
- broken-pipe behavior;
- retry policy;
- cache location and cache-size controls;
- resume behavior;
- concurrency and memory controls;
- expected costs for representative commands;
- examples of piping output into SageMath, Python, Julia, and OSCAR.

The decoding library should expose records directly to callers so that large
analyses do not have to serialize and immediately reparse terabytes of
newline-delimited text.

## 10. Provide language bindings and small reference implementations

### Current shortfall

The official consumer is currently a Rust program. Rust is a good choice for
the high-throughput decoder, but many matroid researchers work primarily in
SageMath, Python, Julia/OSCAR, GAP, or polymake.

### Recommended revision

Keep one authoritative decoder implementation, but provide one or more of:

- a stable C ABI around the Rust library;
- Python bindings;
- a Julia package or Julia example using the library;
- SageMath import examples;
- a simple, deliberately non-optimized reference decoder in Python.

Bindings should yield both the basis string and provenance:

```text
release_id
global_index
n
r
revlex_basis_encoding
```

This would make it easy for downstream projects to retain permanent source
identifiers.

## 11. Publish useful aggregate metadata where feasible

### Current shortfall

The website currently provides only storage-level metadata. Users cannot tell,
without scanning the enumeration, how many records are simple, connected, or
loopless, or how basis counts are distributed.

For the rank-$5$ collection, arbitrary per-record property indexes may be
prohibitively large. The recommendation is therefore not to turn the website
into a conventional row-oriented database.

### Recommended revision

Where the enumeration pipeline can collect summaries economically, publish
aggregate counts such as:

- simple versus non-simple;
- connected versus disconnected;
- loopless and coloopless;
- self-dual, where applicable;
- number-of-bases histogram;
- counts by easily available construction strata.

State whether these aggregates count isomorphism classes. Record the code
revision that computed them.

For properties that are too costly to obtain exhaustively, publish
reproducible sample summaries and label them as estimates, including their
sampling design and uncertainty. Avoid adding a filtering interface unless
there is an index capable of answering the advertised query.

## 12. Improve the enumeration pages

Each public enumeration page could usefully contain the following sections:

1. **Scope:** the exact class of matroids represented.
2. **Status:** complete, partial, candidate complete, or independently
   verified.
3. **Provenance:** authors, method, software, computation, and validation.
4. **Encoding:** named and versioned basis-string and container formats.
5. **Release:** release ID, publication date, manifest hash, and changelog.
6. **Size and access:** compressed and expanded sizes and sequential-access
   warning.
7. **Usage:** copyable commands for iteration, verification, retrieval, and
   sampling.
8. **Citation and license:** dataset citation, mathematical citation, ICARM
   acknowledgment, and license.
9. **Contact:** issue tracker or contact address for corrections.

A downloadable `CITATION.cff`, BibTeX entry, and machine-readable metadata
record would substantially reduce ambiguity in later publications.

## 13. Suggested version-3 manifest

The following sketch combines the most important recommendations. It is not
intended as a rigid schema, but it illustrates the information a downstream
analysis needs.

```json
{
  "schemaVersion": 3,
  "releaseId": "n10r05-v1",
  "n": 10,
  "r": 5,
  "totalRecords": "3222227959444",
  "recordSemantics": "one representative per matroid isomorphism class",
  "completeness": "complete",
  "scope": {
    "includesLoops": true,
    "includesColoops": true,
    "includesParallelElements": true,
    "includesDisconnectedMatroids": true
  },
  "recordEncoding": {
    "name": "revlex-bases",
    "version": 1,
    "lineLength": 252,
    "basisCharacter": "*",
    "nonbasisCharacter": "0",
    "elementLabels": "0-based"
  },
  "containerEncoding": {
    "name": "sz-xz",
    "version": 1,
    "seekable": false
  },
  "provenance": {
    "authors": [],
    "algorithm": "",
    "softwareUrl": "",
    "softwareCommit": "",
    "verification": "",
    "citation": ""
  },
  "release": {
    "published": "2026-06-10T00:00:00Z",
    "license": "",
    "manifestSha256": ""
  },
  "chunks": [
    {
      "url": "",
      "firstIndex": "0",
      "lastIndex": "99999999",
      "count": "100000000",
      "compressedBytes": "0",
      "sha256": ""
    }
  ]
}
```

## 14. A practical staged roadmap

### Stage 1: scientific contract

- Add the scope/completeness statement.
- Add authorship, provenance, citation, and license.
- Document RevLex and `.sz.xz`.
- Add release IDs and chunk hashes.
- Expand the README with realistic access-cost explanations.

These changes are primarily documentation and metadata and do not require
re-encoding the existing data.

### Stage 2: reliable consumer experience

- Publish versioned client binaries.
- Add caching, resume, and verification.
- Add `list`, `info`, `get`, and `sample` commands.
- Add golden fixtures and decoder conformance tests.
- Provide Julia/OSCAR, SageMath, and Python examples.

### Stage 3: access-oriented storage

- Benchmark restart-block sizes.
- Publish independently decodable blocks or checkpoint indexes.
- Make uniform global-index samples economical.
- Add selected aggregate structural metadata.

The first stage would already remove most ambiguity for scholarly use. The
later stages would make the very large rank-$5$ enumeration practically
usable for statistical research rather than only for sequential
high-performance scans.
