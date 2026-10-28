# Fifth iteration: short posting-list merge and ASCII tokenization

These are local measurements on the same 4-vCPU / 4-GiB VM, using the existing
O1 build. They are not platform scores. The official benchmark and scoring
inputs are unchanged.

## Versions

- `before`: original source at `ebaea0dfa835c648248715a4327f9ebfa5f2ebaf`.
- `v5`: previously delivered `ae137397114a298149b572d5ffad424bc5aef975`.
- `v7`: adds direct merging for up to three posting lists and batch projection.
- `v8`: experiments with document-wide lowercasing while retaining the analyzer.
- `v9`: replaces that experiment with a bounded ASCII scanner, preserving the
  analyzer fallback for other documents and collations.
- `v10`: v9 plus equivalent binary-charset document-ID comparison.

`*-full.txt` use all official default parameters, including index construction.
`v9-v5-control.txt` skips loading and is a diagnostic comparison only.
The `v10-*-stable.txt` reports use `SKIP_LOAD=1`, `SAMPLES=5`,
`QUERY_ROUNDS=1000`, in the order v5, v10, v10, v5. They compare identical
persisted data without index rebuilds. Do not feed them to the full-run scorer.

Both good and poor intermediate full runs are retained. VM scheduling and SQL
round-trip costs vary substantially; no outliers are removed, and SELECT 1
time is not subtracted from results.

## Correctness and reproducibility

- Expanded established mysqltest expectations were recorded with `before`.
- `fts-beng-generate.py` generates 460 fixed-seed BENG calls, including all
  ASCII bytes, controls, punctuation, Unicode fallback, two UTF8 collations,
  and the 4095/4096/4097-byte fast-path boundary.
- `fts-merge-generate.py` generates 37 queries covering 1/2/3/4 terms, absent
  terms, term order, Boolean search, scores, LIMIT and OFFSET.
- `fts-snapshot.py` captures four complete document-ID/BM25 result sets.
- `fts-verify-v10.sh` records the final query checks and ABBA measurement order.
- `sources.sha256` contains normalized-LF source hashes, compared between the
  local checkout and the VM before collecting results.

Report `git_dirty=1` reflects the VM source checkout during builds. Version
labels, source hashes and the binary hash identify the executable tested.
