# Roadmap

This roadmap is a working guide, not a contract.

NexusUI should evolve from real application pressure. The best next feature is the one needed by the next actual tool.

## Phase 1: Stabilize core behavior

The first priority is predictable control behavior.

Important work:

- keep one authoritative focused control per window
- reject invalid focus targets consistently
- finish structural Tab traversal behavior
- keep mouse capture reliable
- route popups as overlays
- make wheel routing consistent with coordinate helpers
- harden clipping and viewport behavior

## Phase 2: Clean the project plan

`project_plan.md` should remain accurate enough to guide work.

Useful updates:

- move implemented controls into the completed or initial bucket
- separate backlog controls from controls needing hardening
- remove stale designer-era language
- include current architecture notes
- include open design areas like data context and file dialogs

## Phase 3: Improve skins

The skin system should become more structured without becoming bloated.

Near-term targets:

- define common control part names
- define common states
- centralize appearance lookup
- convert key controls gradually
- document fallback behavior

## Phase 4: Add missing practical controls

Backlog controls should be added when needed by real applications.

Likely candidates:

- `TNXToolBar`
- `TNXSpinEdit`
- `TNXDateEdit`
- `TNXTimeEdit`
- `TNXColorPicker`
- `TNXFileDialog`

`TNXCodeEdit` should remain a design decision before implementation.

## Phase 5: Design data binding

The data binding layer should be designed before it is coded.

Target ideas:

- `TNXDataContext`
- `TNXObjectContext`
- explicit edit, commit, and cancel behavior
- validation state
- dirty tracking
- simple control binding

The design should avoid arbitrary binding complexity. A small, explicit source-of-truth model is preferred.

## Phase 6: Build a real internal app

A real app will expose missing behavior faster than abstract planning.

Candidate applications:

- budget or burn-rate tool
- file or disk usage viewer
- NexusUI designer/debug tool
- schema or configuration editor

The application should be large enough to exercise layout, input, popups, text editing, scrolling, and data state, but small enough to complete.

## Current near-term issue buckets

### Framework stabilization

- focus validity cleanup
- coordinate helper consistency
- popup keyboard ownership semantics
- wheel routing cleanup

### Documentation and planning

- keep docs aligned with implementation
- keep project plan accurate
- document design decisions as they harden

### Backlog controls

- toolbar
- spin edit
- date/time edits
- color picker
- file dialog
- code edit decision

### Data binding

- design note first
- first-pass API second
- implementation only after agreement
