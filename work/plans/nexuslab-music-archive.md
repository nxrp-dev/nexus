# Work Plan: NexusLab Music Archive

## Inputs

- Source request: pasted ChatGPT request attached in the Codex session.
- Human clarification: develop this as an entirely separate project in NexusLab.
- Existing constraints:
  - This is a work plan only.
  - Do not modify production Nexus source during this pass.
  - The plan artifact lives in `work/plans/`.
  - The application itself should live under the sibling lab workspace, proposed as `C:\gitdev\nexus-lab\MusicArchiveNX`.
  - NexusUI must present the UI, but the UI must not execute SQL, store audio bytes, or own decoder internals.

## Summary

Build a new NexusLab application, `MusicArchiveNX`, for archiving user-owned music files. The application should keep catalog data and imported audio content in SQLite, preserve original source provenance, detect duplicate imports from file content, provide metadata/category/tag browsing, play recordings, and allow precise time-segment annotations.

The first implementation should be application-specific. It should use Nexus and NexusUI where they are already appropriate, but it should not turn the first music archive app into a universal database framework, generic media platform, or broad asset-management subsystem.

## Verified Findings

- `C:\gitdev\nexus-lab` exists as a sibling lab workspace with separate app folders: `LifeStatNX`, `SpaceTraderNX`, `SwarmNX`, and `rogue`.
- `SwarmNX` is the clearest current NexusLab app pattern:
  - `SwarmNX.lpr` creates one app object and calls `Run`.
  - `src/obSwarmClientApp.pas` owns runtime setup, skin/resource preparation, controller creation, and `Application.Initialize`.
  - `src/obSwarmMainWindow.pas` composes NexusUI controls and calls a controller.
  - `src/obSwarmTorrentController.pas` owns application commands and domain coordination.
  - `src/obSwarmTorrentViewModel.pas` presents read-only UI state.
- `SwarmNX.lpi` uses project-local `src` plus relative references into `..\..\nexus\NexusUI`, `..\..\nexus\NexusNet\src\torrent`, `..\..\nexus\lib\synapse`, and common SDL unit paths.
- `NexusUI/example/LifeStatNXL.lpr` demonstrates the broadest current NexusUI control surface.
- Current useful NexusUI controls include:
  - main application/window lifecycle: `TNXApplication`, `TNXWindow`, `TNXWindowManager`
  - layout and containers: `TNXPanel`, `TNXGroupBox`, `TNXSplitPanel`, `TNXSplitter`, `TNXTabControl`
  - command/navigation surfaces: `TNXMainMenu`, `TNXPopupMenu`, `TNXToolbar`, `TNXStatusBar`
  - browsing/editing controls: `TNXTreeList`, `TNXTreeView`, `TNXGrid`, `TNXListBox`, `TNXEditBox`, `TNXMemo`, `TNXComboBox`, `TNXCheckBox`, `TNXRadioButton`, `TNXDateEdit`, `TNXTimeEdit`, `TNXPropertyEditor`
  - feedback/playback-adjacent controls: `TNXProgressBar`, `TNXTrackBar`, `TNXLabel`, `TNXButton`
  - dialogs: `TNXFileDialog`, `TNXMessageDialog`
- `TNXFileDialog` supports open, save, and folder selection through `ShowOpen`, `ShowSave`, and `ShowSelectFolder`.
- `TNXFileSystemProvider` supports roots, special folders, directory listing, parent path lookup, and file/directory existence checks. It is an interactive directory provider, not a recursive import engine.
- `TNXPersistObject`, `TNXPersistList`, and `TNXPersistBinary` provide JSON-oriented object persistence and Base64 stream persistence. They are suitable for settings, skins, manifests, and small object graphs, not for storing a music archive catalog or audio files.
- SQLite is already used through FPC `SQLDB` and `SQLite3Conn` in `NexusTools/LS/src/service/obNXLSSymbolCache.pas`, but that class is specific to language-server symbol caching. It is evidence that SQLite works in the toolchain, not a reusable catalog repository.
- `NexusSchema` is template-driven and currently documents Firebird-oriented database generation. It has no current SQLite schema or migration generator.
- Hashing is available through FPC/Synapse-style units already used by the repository. `NexusNet` uses `sha1` for torrent piece and info hashes. This can inform implementation, but the archive app should choose a content hash suited to duplicate identity instead of reusing torrent-specific types.
- No current Nexus audio playback, decoder, metadata inspection, waveform, or media-library subsystem was found.
- NexusTest exists and provides conventions for explicit tests, assertions, result objects, and host/module execution. Some existing tests are simpler standalone Pascal test programs, such as `NexusNet/tests/NexusNetTorrentTests.lpr`.

## Architecture Problem

The requested application crosses several responsibilities that can easily collapse into a single overgrown UI/controller object:

- catalog persistence
- SQLite audio BLOB storage
- folder scanning and import workflow
- duplicate detection
- provenance tracking
- media metadata inspection
- playback device/decoder state
- annotation editing
- search/filtering
- NexusUI presentation

The root architecture problem is ownership separation. The UI should present state and send commands. The catalog should own SQL and transactions. The audio store should own imported audio BLOB storage and streaming. The importer should coordinate a bounded import workflow without becoming the whole application controller. Playback should hide decoder/device internals from UI controls. Annotation and metadata behavior should be persisted through the catalog contract.

## Target Contract

### Application Boundary

- Owner: `TMusicArchiveApp`
- Responsibilities:
  - initialize NexusUI
  - ensure runtime assets and lab app directories
  - create and destroy the application state, catalog, audio store, importer, playback controller, and main window
  - call `Application.Initialize`, load the skin, build the window, and run the event loop
- State flow:
  - creates long-lived application services
  - gives the main window one command/state facade
- Rendering/input/persistence behavior:
  - does not render controls directly
  - does not execute SQL
  - does not scan folders or decode media

### Application State And Command Coordination

- Owner: `TMusicArchiveController`
- Responsibilities:
  - expose user commands such as open archive, import folder, select recording, save metadata, assign categories/tags, play/pause/stop/seek, create annotation, delete annotation, search/filter
  - coordinate catalog, audio store, importer, metadata reader, and playback service
  - build view models for the main window
  - report command results, recoverable errors, and progress
- State flow:
  - owns current archive database path, selected recording ID, selected annotation ID, current filter state, and current playback selection
  - returns immutable or replaceable view-model objects to the UI
- Rendering/input/persistence behavior:
  - owns no NexusUI controls
  - does not contain low-level SQL strings except through repository calls
  - does not copy audio bytes directly
  - does not own decoder internals

### Archive Database Access

- Owner: `TMusicArchiveCatalog`
- Responsibilities:
  - own SQLite connection and transaction lifecycle
  - create and migrate schema
  - provide recording/category/tag/annotation CRUD
  - provide duplicate lookup by content hash
  - provide search/filter queries
  - persist import provenance, recording metadata, and audio-content metadata
- State flow:
  - receives explicit record DTOs from controller/importer
  - returns DTOs or view-query result records, not UI controls
- Rendering/input/persistence behavior:
  - executes SQL
  - does not manipulate NexusUI
  - does not store audio bytes
  - does not inspect audio decoders

### SQLite Audio BLOB Storage

- Owner: `TMusicArchiveBlobStore`
- Responsibilities:
  - own imported audio content stored in SQLite BLOB tables
  - stream source file bytes into the database without requiring whole-track memory buffers
  - expose read streams or temporary playback extraction for selected recordings, depending on backend requirements
  - verify stored BLOB size and content hash
  - keep audio-content writes inside catalog transactions
  - keep large BLOB behavior explicit through page-size/cache/WAL choices and tests
- State flow:
  - receives source file path, stable recording ID, content hash, and file facts
  - writes audio bytes into recording BLOB storage and returns stored-content facts
- Rendering/input/persistence behavior:
  - executes only audio-content SQL through the catalog-owned connection/transaction contract
  - does not update UI controls
  - does not decode media metadata beyond raw file facts

### Folder Import

- Owner: `TMusicArchiveImporter`
- Responsibilities:
  - scan selected source folders recursively or non-recursively
  - filter supported audio extensions
  - validate media through metadata reader
  - calculate content hash
  - check duplicates through catalog
  - stream accepted files into SQLite audio storage
  - commit catalog rows through catalog
  - track progress, cancellation, per-file errors, and final summary
- State flow:
  - receives import options and callback/events
  - coordinates catalog and audio store through explicit interfaces
- Rendering/input/persistence behavior:
  - does not own application-level selection state
  - does not own NexusUI controls
  - does not become a general application controller

### Duplicate Detection

- Owner: `TMusicArchiveDuplicateDetector`
- Responsibilities:
  - compute and normalize content hashes
  - optionally short-circuit with file size before full hash
  - query catalog for existing recordings with matching hash
- State flow:
  - returns duplicate status for importer decisions
- Rendering/input/persistence behavior:
  - does not store audio bytes
  - does not own SQL connection directly if catalog can provide the lookup

### Source Provenance

- Owner: catalog entity `RecordingSource`
- Responsibilities:
  - preserve original source path, original filename, import date, observed size, observed modified timestamp, and source folder/import batch identity
- State flow:
  - written during import
  - readable from recording detail UI
- Rendering/input/persistence behavior:
  - provenance is not derived from stored audio content and is not rewritten when the original file moves

### Audio Metadata Inspection

- Owner: `TMusicMetadataReader`
- Responsibilities:
  - validate supported media files
  - discover format, duration, sample rate, channel count, and optional embedded title/date where available
- State flow:
  - returns metadata DTOs to importer/controller
- Rendering/input/persistence behavior:
  - does not persist directly
  - does not manipulate playback state
  - does not own UI controls

### Playback And Seeking

- Owner: `TMusicPlaybackController`
- Responsibilities:
  - open selected recording content through the audio store
  - play, pause, stop, seek
  - expose current position, duration, volume, playback state, end-of-track, and errors
  - hide the selected audio backend
- State flow:
  - controller calls playback commands
  - UI receives playback view state from main controller
- Rendering/input/persistence behavior:
  - does not execute SQL
  - does not own annotation records
  - does not render timeline UI

### Categories And Tags

- Owner: catalog entities `Category`, `RecordingCategory`, `Tag`, `RecordingTag`
- Responsibilities:
  - categories provide primary archive organization
  - tags provide flexible multi-label classification
  - a recording may have multiple categories and multiple tags unless product input later restricts categories to one primary category
- State flow:
  - category tree/list and tag filters are view queries
  - edits go through controller to catalog
- Rendering/input/persistence behavior:
  - category/tag persistence stays in the catalog

### Time-Segment Annotations

- Owner: catalog entity `Annotation`
- Responsibilities:
  - identify recording, exact start, exact end, label/title, body text, and optional annotation type/category
  - validate start/end ordering and range within recording duration when duration is known
- State flow:
  - timeline UI selects a range
  - controller creates/updates annotation through catalog
  - selecting an annotation asks playback to seek to annotation start
- Rendering/input/persistence behavior:
  - annotations do not own playback
  - playback does not own annotations

### Search And Filtering

- Owner: `TMusicArchiveSearch`
- Responsibilities:
  - build query options for title, description, source path, category, tags, annotation text, format, and date ranges
  - keep SQL execution inside catalog
- State flow:
  - UI updates search options through controller
  - controller requests catalog result sets
- Rendering/input/persistence behavior:
  - search does not own UI controls
  - search does not own database connection

### Waveform Or Timeline Cache

- Owner: `TMusicWaveformCache` only when waveform work begins
- Responsibilities:
  - generate, store, read, and invalidate derived waveform data
  - key cache rows/files by recording ID, stored content hash, and algorithm version
- State flow:
  - controller requests waveform data for a selected recording
  - timeline control receives display-ready samples
- Rendering/input/persistence behavior:
  - cache data is rebuildable
  - missing or stale waveform data is not catalog corruption

### NexusUI Presentation Controls

- Owner: `TMusicMainWindow` and specialized NexusUI controls
- Responsibilities:
  - create and position controls
  - translate user input into controller commands
  - render view models
  - manage visual selection affordances
- State flow:
  - consumes controller-built view models
  - sends commands/events back to controller
- Rendering/input/persistence behavior:
  - no SQL
  - no audio BLOB streaming
  - no decoder internals
  - specialized timeline/waveform controls own rendering and hit testing only

## Scope

- Add a new NexusLab project folder outside the production Nexus tree:
  - `C:\gitdev\nexus-lab\MusicArchiveNX\MusicArchiveNX.lpr`
  - `C:\gitdev\nexus-lab\MusicArchiveNX\MusicArchiveNX.lpi`
  - `C:\gitdev\nexus-lab\MusicArchiveNX\src\...`
  - `C:\gitdev\nexus-lab\MusicArchiveNX\resources\...`
  - `C:\gitdev\nexus-lab\MusicArchiveNX\skins\...`
  - `C:\gitdev\nexus-lab\MusicArchiveNX\tests\...`
- Use NexusUI from `C:\gitdev\nexus\NexusUI`.
- Use FPC `SQLDB` and `SQLite3Conn` directly in the app-specific catalog first.
- Store imported audio content inside SQLite BLOB storage. Do not keep a parallel managed audio-file tree as the primary archive.
- Add only app-specific audio/media code until a second Nexus app needs the same functionality.
- Add a specialized NexusUI timeline control only if existing controls cannot support usable annotation selection.

## Out Of Scope

- No implementation during work-plan creation.
- No production Nexus source edits until the implementation plan is explicitly approved.
- No universal Nexus database framework.
- No generic Nexus media framework.
- No plugin system.
- No arbitrary digital-asset-management framework.
- No Base64 JSON storage of audio files.
- No managed filesystem audio store as the default archive model.
- No broad migration of NexusLS SQLite cache code into a shared abstraction unless later evidence proves a shared need.
- No waveform-first design. Basic annotations can ship with numeric positions and a timeline before waveform rendering exists.
- No audio-device-dependent tests in the default unit-test run.

## Proposed NexusLab Project Structure

```text
C:\gitdev\nexus-lab\MusicArchiveNX\
  MusicArchiveNX.lpr
  MusicArchiveNX.lpi
  resources\
  skins\
  src\
    tpMusicArchiveTypes.pas
    obMusicArchiveApp.pas
    obMusicArchiveController.pas
    obMusicArchiveViewModels.pas
    obMusicMainWindow.pas
    obMusicArchiveCatalog.pas
    obMusicArchiveSchema.pas
    obMusicArchiveBlobStore.pas
    obMusicArchiveImporter.pas
    obMusicDuplicateDetector.pas
    obMusicMetadataReader.pas
    obMusicPlaybackController.pas
    obMusicSearch.pas
    obMusicTimelineControl.pas
    obMusicWaveformCache.pas
  tests\
    MusicArchiveTests.lpr
```

The `.lpi` should mirror the SwarmNX shape: project-local `src`, relative paths into `..\..\nexus\NexusUI`, `..\..\nexus\NexusLib\src` if needed, common SDL unit paths, and FPC database/hash unit paths required for SQLite and hashing.

## Proposed Units And Major Classes

### `tpMusicArchiveTypes.pas`

- Owns:
  - shared records/enums for IDs, import options, import results, media metadata, playback state, annotation ranges, search criteria
- Does not own:
  - SQL connection
  - audio BLOB storage
  - UI controls
- Called by:
  - nearly all app-specific units
- Calls:
  - basic RTL units only
- Reason not existing:
  - no current shared Nexus music/archive type unit exists.

### `obMusicArchiveApp.pas`

- Owns:
  - top-level app lifecycle and service composition
- Does not own:
  - individual command logic
  - SQL implementation
  - UI rendering details
- Called by:
  - `MusicArchiveNX.lpr`
- Calls:
  - `obNXApplication`, controller, catalog, audio store, playback controller, main window
- Reason not existing:
  - current lab apps have per-app lifecycle classes; this follows `obSwarmClientApp`.

### `obMusicArchiveController.pas`

- Owns:
  - current archive session state and command coordination
- Does not own:
  - SQL strings
  - raw audio BLOB streaming routines
  - decoder internals
  - NexusUI controls
- Called by:
  - `TMusicMainWindow`
- Calls:
  - catalog, importer, audio store, metadata reader, playback controller, search, waveform cache when present
- Reason not existing:
  - SwarmNX has an app-specific controller; the music archive needs its own bounded command coordinator.

### `obMusicArchiveViewModels.pas`

- Owns:
  - immutable/display-oriented state for navigation, recording lists, selected recording details, annotations, import progress, playback state
- Does not own:
  - persistence
  - command behavior
- Called by:
  - controller and main window
- Calls:
  - shared type unit
- Reason not existing:
  - prevents UI controls from consuming catalog DTOs directly.

### `obMusicMainWindow.pas`

- Owns:
  - NexusUI control creation, layout, event handlers, and view refresh
- Does not own:
  - SQL
  - audio BLOB storage
  - importer recursion
  - decoder state
- Called by:
  - app lifecycle object
- Calls:
  - controller and NexusUI controls
- Reason not existing:
  - app-specific UI composition belongs in NexusLab, as with `obSwarmMainWindow`.

### `obMusicArchiveCatalog.pas`

- Owns:
  - SQLite connection, schema creation, migrations, transactions, repository methods
- Does not own:
  - UI controls
  - decoder-specific playback streams
  - decoder/device access
- Called by:
  - controller, importer, duplicate detector/search through explicit methods
- Calls:
  - `SQLDB`, `SQLite3Conn`, `DB`, schema unit
- Reason not existing:
  - `TNXLSSymbolCache` is a symbol-cache implementation, not a reusable music archive catalog.

### `obMusicArchiveSchema.pas`

- Owns:
  - schema version constants and SQL DDL strings for this app
- Does not own:
  - live connection or query execution
- Called by:
  - catalog
- Calls:
  - basic RTL only
- Reason not existing:
  - NexusSchema has no SQLite target today; app-local schema keeps scope narrow.

### `obMusicArchiveBlobStore.pas`

- Owns:
  - SQLite audio-content BLOB writes, reads, chunking/streaming policy, and stored-content integrity checks
- Does not own:
  - recording metadata SQL beyond the audio-content rows it is explicitly asked to write
  - duplicate policy
  - UI progress rendering
- Called by:
  - importer and controller maintenance commands
- Calls:
  - catalog transaction/connection contract, RTL stream units, and hash helper
- Reason not existing:
  - `TNXPersistBinary` stores Base64 JSON and is not appropriate for large archive content; `TNXTorrentFileStore` is torrent-specific and maps piece ranges, not database-owned archive content.

### `obMusicArchiveImporter.pas`

- Owns:
  - import workflow and progress state
- Does not own:
  - global application state
  - SQL implementation details
  - UI controls
- Called by:
  - controller
- Calls:
  - filesystem scanner/helper, metadata reader, duplicate detector, audio store, catalog
- Reason not existing:
  - `TNXFileSystemProvider` is interactive directory listing, not recursive import.

### `obMusicDuplicateDetector.pas`

- Owns:
  - content hash calculation and duplicate decision helpers
- Does not own:
  - file placement
  - SQL connection
  - UI status
- Called by:
  - importer and maintenance commands
- Calls:
  - catalog lookup methods and hash routine
- Reason not existing:
  - torrent hash code is piece-specific; music archive duplicates need whole-file identity.

### `obMusicMetadataReader.pas`

- Owns:
  - media validation and metadata extraction contract
- Does not own:
  - playback control
  - database writes
  - UI display
- Called by:
  - importer and controller refresh/repair commands
- Calls:
  - selected audio/metadata backend
- Reason not existing:
  - no current Nexus media inspection support exists.

### `obMusicPlaybackController.pas`

- Owns:
  - audio backend lifecycle, current recording playback state, seeking, volume, end-of-track/error state
- Does not own:
  - annotations
  - catalog writes
  - NexusUI rendering
- Called by:
  - controller
- Calls:
  - selected audio backend
- Reason not existing:
  - no current Nexus playback abstraction exists.

### `obMusicSearch.pas`

- Owns:
  - search criteria normalization and query intent
- Does not own:
  - database connection
  - UI controls
- Called by:
  - controller
- Calls:
  - catalog query methods
- Reason not existing:
  - search belongs to the application model; no current reusable Nexus search layer exists.

### `obMusicTimelineControl.pas`

- Owns:
  - rendering a selected recording duration, playhead, selected time range, and annotation markers
  - hit testing and mouse/keyboard selection gestures
- Does not own:
  - playback device
  - annotation persistence
  - SQL
  - waveform generation
- Called by:
  - main window
- Calls:
  - NexusUI canvas/control APIs only
- Reason not existing:
  - `TNXTrackBar` can represent a scalar position, but it cannot represent range selection and annotation markers cleanly.

### `obMusicWaveformCache.pas`

- Owns:
  - optional later waveform cache generation and invalidation
- Does not own:
  - source audio identity
  - catalog recording rows
  - UI rendering
- Called by:
  - controller after basic playback/annotations exist
- Calls:
  - metadata/decoder backend and file/cache storage
- Reason not existing:
  - waveform data is app-specific derived data until another Nexus app needs the same facility.

## Initial Database Schema

Use SQLite for catalog data and imported audio content. Store waveform or analysis data as rebuildable cache, either in SQLite cache tables or separate cache files under the application cache area.

Use integer primary keys for local rows plus stable public IDs for recordings. The stable recording ID should be generated at import time and should not change when the file is renamed, retitled, or moved inside managed storage.

Initial schema fragment:

```sql
create table archive_meta (
  key text primary key,
  value text not null
);

create table recording (
  id integer primary key,
  stable_id text not null unique,
  title text not null,
  description text not null default '',
  imported_at_utc text not null,
  original_filename text not null,
  original_source_path text not null,
  content_hash text not null,
  content_hash_algorithm text not null,
  file_size_bytes integer not null,
  media_format text not null,
  duration_ms integer,
  sample_rate_hz integer,
  channel_count integer,
  recorded_at_utc text,
  created_at_utc text not null,
  updated_at_utc text not null
);

create unique index idx_recording_content_hash
  on recording(content_hash_algorithm, content_hash);

create table recording_content (
  recording_id integer primary key,
  content blob not null,
  content_size_bytes integer not null,
  content_hash text not null,
  content_hash_algorithm text not null,
  stored_at_utc text not null,
  foreign key(recording_id) references recording(id) on delete cascade,
  check(content_size_bytes >= 0)
);

create table recording_content_chunk (
  recording_id integer not null,
  chunk_index integer not null,
  chunk_offset integer not null,
  content blob not null,
  content_size_bytes integer not null,
  primary key(recording_id, chunk_index),
  foreign key(recording_id) references recording(id) on delete cascade,
  check(chunk_index >= 0),
  check(chunk_offset >= 0),
  check(content_size_bytes > 0)
);

create table recording_source (
  id integer primary key,
  recording_id integer not null,
  source_path text not null,
  source_filename text not null,
  source_root text not null,
  source_modified_at_utc text,
  source_size_bytes integer,
  imported_at_utc text not null,
  import_batch_id text not null,
  foreign key(recording_id) references recording(id) on delete cascade
);

create table category (
  id integer primary key,
  parent_id integer,
  name text not null,
  sort_order integer not null default 0,
  foreign key(parent_id) references category(id) on delete set null
);

create unique index idx_category_parent_name
  on category(parent_id, name);

create table recording_category (
  recording_id integer not null,
  category_id integer not null,
  primary key(recording_id, category_id),
  foreign key(recording_id) references recording(id) on delete cascade,
  foreign key(category_id) references category(id) on delete cascade
);

create table tag (
  id integer primary key,
  name text not null unique
);

create table recording_tag (
  recording_id integer not null,
  tag_id integer not null,
  primary key(recording_id, tag_id),
  foreign key(recording_id) references recording(id) on delete cascade,
  foreign key(tag_id) references tag(id) on delete cascade
);

create table annotation (
  id integer primary key,
  recording_id integer not null,
  start_ms integer not null,
  end_ms integer not null,
  title text not null,
  body text not null default '',
  annotation_type text not null default '',
  created_at_utc text not null,
  updated_at_utc text not null,
  foreign key(recording_id) references recording(id) on delete cascade,
  check(start_ms >= 0),
  check(end_ms > start_ms)
);

create index idx_annotation_recording_range
  on annotation(recording_id, start_ms, end_ms);
```

Time positions should initially be stored as integer milliseconds. Milliseconds are precise enough for first-pass music annotation and map cleanly to UI display, playback seeking, and SQLite integer storage. Do not store positions as floating-point seconds. If sample-accurate annotation becomes a product requirement, add sample-position fields later after the audio metadata reader can guarantee sample rate and decoder positioning semantics.

Categories should initially support a hierarchy through `parent_id` and allow a recording to belong to multiple categories through `recording_category`. Tags remain flat, flexible labels. The product distinction should be:

- categories: curated archive organization, suitable for navigation
- tags: looser cross-cutting descriptors, suitable for filtering

## Storage Model

- Catalog:
  - SQLite database, for example `MusicArchiveNX\data\archive.sqlite` or a user-selected archive database file.
  - the database is the archive container: metadata, provenance, categories, tags, annotations, and imported audio bytes live together.
- Audio content:
  - imported source files are stored as SQLite BLOB content.
  - the simple first-pass schema may use one `recording_content.content` BLOB per recording.
  - if local FPC SQLite bindings or playback needs make whole-row BLOB reads impractical, use `recording_content_chunk` with deterministic chunk sizes such as 1 MiB.
  - chunked storage is preferred if implementation cannot expose reliable SQLite incremental BLOB I/O.
  - do not use `TNXPersistBinary` or Base64 JSON for audio content.
- Source provenance:
  - always stored separately from stored content.
  - original source path and original filename are immutable import facts.
- Derived data:
  - waveform cache rows or external cache files are rebuildable.
  - invalidate when content hash, file size, algorithm version, or cache schema version changes.

Duplicate detection should be content-based. The importer may first group by file size for efficiency, but the decision must use a full content hash calculated while reading the source file. The first implementation can use SHA-1 because the repository already uses it and this is duplicate detection rather than adversarial security. The plan should leave the algorithm name in the database so SHA-256 can be adopted later without changing identity semantics.

SQLite BLOB storage is viable for this application, but the implementation must treat music files as large content:

- avoid loading whole recordings into memory for import, export, integrity checks, or playback handoff
- prefer streaming source-file reads into SQLite
- use explicit transactions so metadata and BLOB content commit or roll back together
- set and verify practical SQLite pragmas during implementation, especially page size, WAL mode, synchronous mode, and cache size
- test database growth, backup/copy behavior, and vacuum expectations with fixture files larger than typical metadata-only records
- keep an export command in scope for later maintenance so recordings can be recovered from the database as ordinary audio files

## Import Sequence

1. User selects a source folder with `TNXFileDialog.ShowSelectFolder`.
2. UI asks the controller to start import with options:
   - source folder
   - recursive or non-recursive
   - supported extensions
   - duplicate behavior
3. Controller creates an import batch ID and calls the importer.
4. Importer scans the folder using app-specific recursive scanner code.
5. Scanner filters by supported extensions before metadata work.
6. Importer validates each candidate through `TMusicMetadataReader`.
7. Importer calculates content hash from file bytes.
8. Duplicate detector asks catalog whether the hash is already present.
9. If duplicate:
   - skip by default
   - record import attempt/source provenance only if product decision later wants multiple source sightings for one recording
   - include duplicate in import summary
10. If new:
   - generate stable recording ID
   - start catalog transaction
   - insert recording and source rows
   - stream source file bytes into `recording_content` or `recording_content_chunk`
   - verify stored byte count and stored content hash
   - commit transaction
11. Progress callback reports scanned count, imported count, duplicate count, skipped count, error count, current file, and cancellation state.
12. UI refreshes view model after import completes or is cancelled.

## Transaction And Recovery Behavior

- Database metadata row created but BLOB streaming fails:
  - rollback the transaction so recording, source, and partial content rows disappear together.
- BLOB content written but metadata insertion fails:
  - keep content writes inside the same transaction as metadata; rollback removes the partial content.
- Chunked content partially written:
  - rollback the active transaction.
  - on next open, maintenance may also remove rows from `recording_content_chunk` that do not have a matching `recording` row if any transaction boundary was interrupted by process failure.
- Import cancelled:
  - finish the current safe read/write step, rollback any active transaction, return summary with cancellation flag.
- Imported file already exists:
  - if same content hash, treat as duplicate.
- Original source file later moves or disappears:
  - no catalog corruption. Provenance remains as historical source data.
- Stored audio content missing:
  - foreign-key constraints should normally prevent this.
  - maintenance reports any recording without matching content as corrupt.
- Stored audio content altered:
  - integrity check streams stored BLOB/chunks, recalculates hash, and reports mismatch; do not silently update the stored hash.
- Database grows unexpectedly large:
  - maintenance should report total content size and database file size.
  - vacuum/repack remains an explicit maintenance operation, not an automatic action during ordinary imports.

## Playback And Annotation Design

### Audio Backend

No existing Nexus audio playback layer was found. The first approved implementation must choose a small backend based on what is practical in the local FPC/Windows toolchain.

Recommended first pass:

- define `TMusicPlaybackController` behind an app-specific interface
- implement one concrete Windows-capable backend after verifying available FPC bindings
- prefer a backend that can provide duration, seek, current position, and common audio format support
- keep any backend DLLs or dynamic dependencies in the NexusLab app runtime folder, not in production Nexus source

Backend candidates to verify during implementation:

- SDL2_mixer if available and sufficient for the target formats, though duration/seek support may be limiting
- BASS or another small audio library if licensing and local availability are acceptable
- platform media APIs only if they can be wrapped without making NexusUI platform-specific

### Basic Playback

The controller exposes:

- open selected recording
- stream or temporarily materialize selected recording content for the selected backend
- play
- pause
- stop
- seek to millisecond position
- set volume
- poll or receive current position
- handle end-of-track
- report decoder/device errors

The UI uses buttons plus a `TNXTrackBar` or `TMusicTimelineControl` for position. Playback state is reflected through view models.

### Annotation

The first usable annotation version should not require waveform generation.

- `TMusicTimelineControl` renders duration, playhead, range selection, and existing annotations.
- User selects a start/end range.
- UI calls controller to create annotation from selected range.
- Controller validates against selected recording and duration.
- Catalog persists integer millisecond positions.
- Selecting an annotation asks playback to seek to `start_ms`.
- Editing/deleting annotations goes through controller and catalog.

### Waveform

Waveform work is a later phase.

- waveform samples are derived cache data
- generation belongs to `TMusicWaveformCache`
- rendering belongs to `TMusicTimelineControl`
- invalidation uses recording ID, content hash, file size, and waveform algorithm version
- missing waveform cache should degrade to plain timeline rendering

## NexusUI Structure

Initial UI should use existing NexusUI controls and the lab app composition style.

Proposed first window:

- top command surface:
  - `TNXToolbar` with import, rescan, play, pause, stop, integrity check
  - optional `TNXMainMenu` for archive/file commands
- left navigation:
  - `TNXTreeList` or `TNXTreeView` for category hierarchy and saved filters
- center recording list:
  - `TNXGrid` for title, duration, format, imported date, category/tag summary, availability
- right detail panel:
  - `TNXEditBox` for title
  - `TNXMemo` for description
  - `TNXComboBox`/`TNXListBox`/checkbox-style controls for category/tag assignment
  - annotation list using `TNXGrid` or `TNXListBox`
- bottom playback and timeline:
  - `TNXButton` controls for play/pause/stop
  - `TNXTrackBar` for simple playback position at first
  - `TMusicTimelineControl` once range annotations need a real selection surface
  - volume through `TNXTrackBar`
- status/progress:
  - `TNXStatusBar` for current command state
  - `TNXProgressBar` for imports

The UI should not copy a foreign framework architecture into NexusUI. It should be a direct retained-control composition like `LifeStatNXL` and `SwarmNX`, with application behavior behind a controller.

## Staged Implementation Plan

### Phase 1: Boundary And Skeleton

- Create `C:\gitdev\nexus-lab\MusicArchiveNX`.
- Add `.lpr`, `.lpi`, `src`, `resources`, `skins`, and `tests`.
- Follow `SwarmNX` app/controller/main-window structure.
- Create empty app-specific service classes and view models.
- Build a NexusUI shell with navigation, recording list, details, playback strip, and status bar.
- Verification:
  - `lazbuild C:\gitdev\nexus-lab\MusicArchiveNX\MusicArchiveNX.lpi`
  - run the app and confirm the shell opens with default skin.

### Phase 2: Catalog Schema And Repository

- Add app-specific SQLite catalog using `SQLDB` and `SQLite3Conn`.
- Add schema version table, schema creation, and basic migration boundary.
- Implement recording CRUD and list/search queries.
- Add deterministic test database creation under temp directories.
- Verification:
  - catalog tests for schema creation, version row, CRUD, search, and transaction rollback.

### Phase 3: SQLite Audio BLOB Store

- Implement database-owned audio content storage.
- Decide between single-row BLOB storage and chunked BLOB storage after verifying local SQLite/FPC streaming behavior.
- Implement streaming import writes, streaming reads, and stored-content integrity checks.
- Keep BLOB writes inside the same transaction as recording/source metadata.
- Verification:
  - byte-for-byte round trip tests
  - large fixture import without whole-file memory buffering
  - partial write rollback tests
  - missing/altered stored-content checks

### Phase 4: Folder Import And Duplicate Detection

- Implement recursive/non-recursive scanner.
- Implement extension filter and import options.
- Implement content hash calculation.
- Implement duplicate lookup by hash.
- Implement import summary, recoverable errors, and cancellation.
- Persist source provenance.
- Verification:
  - duplicate import detection
  - recursive scanning
  - unsupported extension skip
  - cancelled import cleanup
  - metadata/content rollback combinations

### Phase 5: Browsing And Metadata Editing

- Bind controller view models to the NexusUI shell.
- Show recording rows, selected recording details, source provenance, and availability.
- Save title/description edits.
- Add search text and basic filters.
- Verification:
  - controller/view-model tests where practical
  - manual UI checks for import, selection, edit, refresh, search

### Phase 6: Categories And Tags

- Add category and tag CRUD.
- Add recording-category and recording-tag assignment.
- Render category navigation and tag filters.
- Verification:
  - many-to-many relationship tests
  - category hierarchy tests
  - filter tests
  - manual assignment and browsing checks

### Phase 7: Audio Metadata Reader

- Verify backend/library availability.
- Implement duration, format, sample rate, channel count extraction.
- Integrate metadata extraction into import.
- Verification:
  - supported fixture media
  - unsupported/corrupt media
  - metadata persistence
  - no audio device required for metadata-only tests

### Phase 8: Playback And Seeking

- Implement playback backend wrapper.
- Add controller commands and playback view model.
- Wire UI controls to play/pause/stop/seek/volume.
- Verification:
  - backend-free state transition tests with a fake playback implementation
  - manual audio-device playback test
  - seek and end-of-track manual checks

### Phase 9: Time-Segment Annotations

- Add annotation CRUD and validation.
- Add basic timeline/range selection.
- Navigate from annotation to playback position.
- Verification:
  - annotation range validation
  - create/edit/delete tests
  - seek-to-annotation test with fake playback
  - manual timeline selection checks

### Phase 10: Waveform Cache

- Add waveform generation only after basic annotations are usable.
- Store derived cache data outside core recording identity.
- Render cached waveform in timeline control.
- Verification:
  - cache creation
  - invalidation on content hash or algorithm version change
  - fallback when cache is missing

### Phase 11: Integrity And Recovery

- Add archive maintenance commands:
  - find missing recording-content rows
  - find hash mismatches
  - find incomplete chunk sets if chunked content is used
  - optionally re-link source sightings
  - export selected recordings back to ordinary audio files
- Verification:
  - missing content rows
  - altered stored content
  - incomplete chunks
  - export round trip
  - source disappeared behavior

### Phase 12: Tests And Documentation

- Create `MusicArchiveTests.lpr`.
- Add focused tests for catalog, audio store, importer, duplicate detector, annotations, and controller state.
- Add short project README for archive layout and dependencies.
- Produce a NexusLab source/runtime archive after approved implementation is complete.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

Compile targets:

```text
lazbuild C:\gitdev\nexus-lab\MusicArchiveNX\MusicArchiveNX.lpi
fpc C:\gitdev\nexus-lab\MusicArchiveNX\tests\MusicArchiveTests.lpr
```

Relevant existing compile targets to keep Nexus compatibility in view:

```text
lazbuild NexusUI\example\LifeStatNXL.lpi
lazbuild --build-all NexusTest\NexusTestUI\NexusTestUI.lpi
fpc NexusUI\testNXPersist.lpr
```

Focused greps after implementation:

```text
rg -n "TSQLite3Connection|TSQLQuery|ExecuteDirect" C:\gitdev\nexus-lab\MusicArchiveNX\src
rg -n "TFileStream|CreateBlobStream|sqlite3_blob|recording_content|recording_content_chunk" C:\gitdev\nexus-lab\MusicArchiveNX\src
rg -n "Base64|TNXPersistBinary" C:\gitdev\nexus-lab\MusicArchiveNX\src
```

Expected grep interpretation:

- SQL references should be confined to catalog/schema tests and catalog implementation.
- source-file read references should be confined to importer/audio-store tests and implementation.
- `TNXPersistBinary`/Base64 should not be used for audio storage.

Unit tests:

- schema creation and versioning
- recording CRUD
- category hierarchy and recording-category relationship
- tag and recording-tag relationship
- annotation range validation
- source-provenance preservation
- audio BLOB round trip
- chunk ordering and chunk completeness if chunked storage is used
- duplicate import detection
- interrupted or failed imports
- rollback behavior
- missing recording-content rows
- altered stored content
- unsupported or corrupt media
- recursive folder scanning
- cancellation
- playback state transitions with fake playback backend
- seeking with fake playback backend
- annotation creation and navigation with fake playback backend
- UI command/state coordination where practical through controller/view-model tests

Integration tests:

- create temp archive root
- create catalog
- import fixture audio files
- verify database rows and stored audio content
- re-import same files and verify duplicates
- edit metadata/category/tags
- create annotation and verify persistence

Manual tests:

- app starts from NexusLab project directory
- skin/resources load from runtime location
- select source folder
- import progress updates
- duplicate import summary is understandable
- browse by category
- search by title/tag/source text
- select recording and edit metadata
- play/pause/stop/seek with real audio device
- create annotation from timeline selection
- click annotation and seek to its start
- simulate missing recording-content row and run integrity check

Audio-device tests should be separated from normal unit tests because they depend on local hardware and backend availability.

## Risks And Questions

- Product name is unresolved. `MusicArchiveNX` is a working project name.
- Supported file formats need a first-pass list. Proposed initial filter: `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, pending backend verification.
- Audio backend is unresolved and must be verified locally before implementation.
- Content hash algorithm should be confirmed. Proposed first pass: SHA-1 with stored algorithm name; SHA-256 is preferable if an available FPC unit is confirmed.
- Archive root behavior needs product input:
  - single default archive under app data
  - user-selected archive folder
  - multiple archive databases
- Category policy needs product confirmation:
  - allow multiple categories per recording as proposed
  - or require one primary category plus tags
- Embedded metadata policy needs product input:
  - use embedded title/date when available
  - always default title from original filename
  - present imported metadata as suggestions
- Duplicate provenance policy needs product input:
  - skip duplicates only
  - or record additional source sightings for existing recordings
- Waveform should remain deferred unless annotation usability proves a plain timeline insufficient.

## Acceptance Criteria

The work plan is acceptable if it:

- plans `MusicArchiveNX` as a separate NexusLab project
- keeps Nexus production source unchanged during planning
- identifies reusable NexusUI, filesystem, persistence, SQLite, and testing capabilities from current code
- identifies missing audio/media/waveform capabilities
- defines explicit ownership boundaries
- proposes a normalized SQLite schema
- keeps imported audio files in SQLite BLOB storage, not filesystem storage or Base64 JSON
- preserves original source provenance separately from stored audio content
- uses stable recording identity independent of filename/path
- detects duplicates by content hash
- covers import transaction and recovery behavior
- separates playback from annotation persistence and UI controls
- stages implementation into verifiable increments
- names tests and manual checks
- lists real unresolved product decisions

## Approval Gate

No implementation begins until Kevin explicitly authorizes this MusicArchiveNX work plan.
