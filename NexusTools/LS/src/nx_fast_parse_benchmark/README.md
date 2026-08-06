# NX Fast Parse Benchmark

This archive contains:

- `obNXFastParse.pas` — immutable runtime-built string set using `Length + FirstChar + LastChar` direct buckets.
- `nxFastParseBenchmark.lpr` — console benchmark comparing the original Pascal keyword `or` chain against the new mechanism.

Build:

```bash
fpc nxFastParseBenchmark.lpr
```

Run:

```bash
nxFastParseBenchmark <folder> [repetitions]
```

Example:

```bash
nxFastParseBenchmark c:\dev\nexus 20
```

The benchmark recursively scans `.pas` files, extracts Pascal-style identifiers, lowercases them once, and then runs both keyword mechanisms against the same token array.
