# Nexus Data Binding

`TNXBindingSource` connects a source's current values to bound consumers. The
source owns navigation; the coordinator checks pending edits and synchronizes
values through non-owning CORBA interfaces.

The core lives in `NexusLib/binding`, independently of Nexus UI and fpGUI. It
supports one-way/two-way binding, source-first initialization, conversion,
validation, pending input, and optional source edit sessions. Application code
explicitly submits, commits, cancels, or retries navigation.

See the [binding contracts](../../NexusLib/binding/docs/contracts.md) for the
connection API, source/target obligations, and lifetime rules. The console tests
exercise the real coordinator with ordinary Pascal sources and targets,
including a reusable current-record facade and an object-list source.

Production GUI and data adapters are not included yet. Existing controls still
use direct value access until they implement the endpoint contracts. The core
does not provide indexing, numeric lookup, sorting/filtering, or a View layer.
