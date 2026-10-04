# Nexus SQLite dataset

`TNXSQLiteDataSet` in `src/obNXSQLiteDataSet.pas` inherits directly from FPC
`TDataSet`. It uses this package's `SQLite3Dyn` binding and has no GUI or SQLDB
dependency. `TNXSQLiteConnection` owns the SQLite handle and transactions.

```pascal
lConnection := TNXSQLiteConnection.Create(nil);
lDataSet := TNXSQLiteDataSet.Create(nil);
try
  lConnection.LibraryName := 'path/to/sqlite3.dll';
  lConnection.DatabaseName := 'example.sqlite';
  lDataSet.Connection := lConnection;
  lDataSet.SQL.Text := 'SELECT id, name FROM people ORDER BY name';
  lDataSet.Open;

  lConnection.StartTransaction;
  lDataSet.Edit;
  lDataSet.FieldByName('name').AsUnicodeString := 'Changed';
  lDataSet.Post;
  lConnection.Commit;
finally
  lDataSet.Free;
  lConnection.Free;
end;
```

`Open` accepts one read-only result-producing statement. Named query parameters
use `:name` and `Params`/`ParamByName`. `ExecSQL` executes a non-result-producing
statement. Connection `Execute` serves the same purpose without a dataset.
SQL and identifier strings contain UTF-8, as in the surrounding Nexus framework.

## Storage and editing

The dataset materializes query results for bidirectional navigation. Each
successful `Post` or `Delete` writes to SQLite inside a savepoint, then reloads
the query. Defaults, triggers, SQL ordering and query membership are reflected
in the new snapshot. A failed write retains the edit and runs the normal
dataset error-event path. A successful post has no pending change log;
`UpdateStatus` returns `usUnmodified`.

Without an explicit transaction, releasing the write savepoint commits the
operation. `StartTransaction`/`Commit`/`Rollback` allow multiple operations in
one transaction. Commit posts outstanding dataset edits. Rollback cancels
outstanding edits and refreshes the connection's open datasets. Other open
datasets are independent snapshots; call `Refresh` to observe writes made
through another dataset or external SQL.

Automatic writes require a single source table, its complete primary key in
the result, and unique non-NULL keys. This includes composite primary keys and
`WITHOUT ROWID` tables. Queries without a usable identity remain read-only.
Keys are never inferred from field position. Generated columns are read-only.
Automatic update/delete predicates include original stored values to reject
stale writes. Every write must affect exactly one row.

For explicit mappings, set `UpdateTableName`, optionally `UpdateDatabaseName`,
and `KeyFields` (semicolon-separated result field names). `InsertSQL`,
`UpdateSQL`, and `DeleteSQL` provide caller-defined DML. Their named parameters
may reference `:NEW_field`, `:OLD_field`, `:field`, or query parameters. Insert
SQL should return generated keys through `RETURNING`, in `KeyFields` order.
Update SQL can also return keys. The dataset does not invent updates for
ambiguous joins.

Bookmarks belong to one dataset and one open session. Refresh and writes keep
bookmarks for rows with unchanged keys; editing a key retains that row's
bookmark. Deleted, filtered-out and closed-session bookmarks are invalid.
Refresh and writes recheck key uniqueness. If identity becomes ambiguous, the
dataset becomes read-only and prior bookmarks are invalidated.
`IndexFieldNames` provides local ordering with semicolon-separated field names
and optional `ASC`/`DESC`. Text uses SQLite binary ordering over UTF-8 bytes,
independent of the operating system locale. `Locate` respects the visible view;
`Lookup` does not move or post the current record. Index definitions separate
field names from descending fields. Provider default ordering and the dataset's
`GetIsIndexField` hook describe the explicit local index; SQL ordering is not
inferred from primary keys. `MasterSource` binds matching query parameters to
master fields and reloads the detail when the master changes.

## Fields, filtering and blobs

Integer declarations map to `ftLargeint`; real declarations to `ftFloat`;
decimal/numeric declarations to `ftFMTBcd`; date/time declarations to their
corresponding field types; bounded character declarations to `ftWideString`;
unbounded text to `ftWideMemo`; and blobs to `ftBlob`. Persistent fields or
explicit `FieldDefs` can select another compatible type. Untyped expressions
are inferred from the complete result; mixed storage classes require an
explicit field. SQLite's own affinity and numeric precision rules still apply.
Incompatible values and oversized fixed fields raise errors rather than
silently truncating data.

Timezone-free date and timestamp text preserves its stored calendar value;
reading it does not apply the machine's timezone offset.

FPC 3.2.2 exposes `TField.IsIndexField` but never populates its private flag or
calls the dataset's index-field hook. That inherited field property remains
false; use `IndexDefs` to inspect local ordering.

`Filter` uses SQLite predicate syntax, including `IS NULL`, `LIKE`, comparisons
and boolean operators. `foCaseInsensitive` applies SQLite `NOCASE` collation;
LIKE patterns are explicit SQL patterns, not implicit `*` matching.
`OnFilterRecord` can add Pascal filtering. `FindFirst`/`FindNext`/`FindPrior`/
`FindLast` can search the predicate while `Filtered` is false.

Automatically created `TNXSQLiteBlobField` and `TNXSQLiteMemoField` preserve
NULL versus empty values. Use those classes for persistent blob/memo fields
when that distinction is needed: FPC's standard `TBlobField.Clear` uses the
same empty write-stream operation as writing an empty value. Blob variants use
byte arrays. Wide-memo streams contain UTF-16; binary blob streams contain
unaltered bytes. Destroy writable streams before posting. Cancellation or
closing detaches streams; detached writable streams cannot publish changes.

SQLite library leases prevent unloading or replacing the library while
connections are open. Connections and datasets are synchronous and should be
used on their owning thread.

## Verification

The NexusTest suite lives in `test`:

```powershell
lazbuild -B sqlite\test\NXSQLiteTests.lpi
& .\sqlite\output\NXSQLiteTests.exe
```

Run from `packages/foundation/db`. Build output stays in ignored `sqlite/output`.
The Win64 tests use the packaged runtime in `runtime/win64`. The runner stops
at the first failing test so its cause can be reviewed before changes.

The final Win64 run with FPC 3.2.2 passed all 24 tests with range, overflow,
I/O and heap checks enabled, and zero unfreed memory blocks. Other platforms
have not been run.

Corrections made during implementation and verification:

- Implemented all four public `Find*` overrides and their `Found` state.
- Replaced locale-dependent text ordering and equality with binary comparisons.
- Bound master-supplied values in execution copies while preserving the master
  link's `Bound=False` flags; removed a redundant detail refresh before reopening.
- Removed host-timezone adjustments from timezone-free date parsing and used
  field-type conversion when comparing stored date text with edited dates.
- Implemented native/non-native scalar buffer conversion, including FPC's
  Currency-sized `TBCDField` layout.
- Stored booleans as SQLite integers `0` and `1`.
- Preserved UTF-8 SQL bytes instead of encoding SQL and metadata a second time.
- Corrected local index/provider metadata and the dataset's index-field hook.
- Revalidated row identity after refresh and writes, preventing ambiguous keys
  from sharing bookmark identities or remaining writable.
