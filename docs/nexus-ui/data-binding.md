# Nexus UI Data Binding

Nexus UI does not currently have an implemented data binding layer. The repo
tracks the idea in planning notes, but no `TNXDataContext` or `TNXObjectContext`
runtime API exists yet.

## Desired Direction

The data-aware layer should be designed before it is coded. The likely shape is
small and explicit:

- `TNXDataContext`
- `TNXObjectContext`
- field/value state
- dirty tracking
- validation state
- edit, commit, cancel, and end-edit behavior
- simple control binding

## Design Principles

The binding layer should avoid arbitrary binding complexity. Nexus UI favors a
clear source-of-truth model where edit state, validation, and commit/cancel
behavior are visible in the Pascal object graph.

Controls should not gain hidden knowledge of every possible data source. A
binding layer should adapt source state to controls through explicit contracts.

## Before Implementation

Before adding runtime binding classes, write down:

- which object owns edit state
- how validation errors are represented
- when control edits become dirty source values
- how commit and cancel interact with focused controls
- how list/grid/tree controls expose selection and row state
- whether binding belongs in core controls or adapter objects

Until that design exists, application code should set and read control values
directly.
