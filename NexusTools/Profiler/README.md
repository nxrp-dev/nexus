# Nexus Profiler Import

`NexusProfilerImport` imports NexusFPC `.nxp` traces into SQLite for direct
analysis with SQLite tools.

The executable uses the same `sqlite3.dll` runtime as NexusLS. Place it beside
the executable or make it discoverable through `PATH`.

```text
NexusProfilerImport import <database.sqlite> <trace-or-directory> [-run <name>]
```

A directory import is recursive. Every new input/run combination creates one
`nxp_run`; all trace files discovered under the input path belong to that run.
Retries reuse that run.

Import progress is committed atomically to SQLite every 64 MiB of processed
trace data. Running the same command again resumes each unfinished trace from
its last checkpoint. The default run name is the expanded input path so it is
stable across retries. When `-run` is supplied, use the same name to resume.
Checkpoint state is stored only in SQLite; there is no external checkpoint log.

The database preserves metadata and completed calls in the `nxp_*` tables and
materializes procedure totals and call edges during import. Useful views are:

- `v_nxp_hotspots`: totals across every trace in a run;
- `v_nxp_procedure_totals`: per-trace procedure totals;
- `v_nxp_call_edges`: caller/callee totals;
- `v_nxp_trace_summary`: trace completeness, event counts, and issue counts.

For example:

```sql
select name, unit_name, calls, self_seconds, inclusive_seconds
from v_nxp_hotspots
order by self_seconds desc
limit 100;
```

`nxp_import_issue` records discontinuities and unmatched terminal events. The
importer does not invent durations for incomplete data.
