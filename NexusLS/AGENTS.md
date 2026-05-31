# NexusLS Architecture Notes

## JSON-RPC Object Model

NexusLS uses the Nexus JSON-RPC object model intentionally.

A JSON-RPC request class is a command object. It represents an executable protocol command, not a passive data-transfer record and not a manually assembled JSON payload.

A JSON-RPC result class is the returnable result object for a request. It represents the structured response object produced by executing the command.

The `published` section is the structured contract surface for both inbound and outbound protocol values. Published properties define the fields that participate in protocol serialization and deserialization.

This object model is the architecture.

Do not replace it with manually assembled JSON objects, parallel DTOs, compatibility bridges, fallback adapters, transitional shims, or translation layers that duplicate the request/result object structure.

The intended shape is:

- request class = protocol command
- result class = protocol return object
- parameter/object classes = structured protocol values
- published properties = protocol field contract
- request execution = command behavior
- JSON-RPC infrastructure = serialization and deserialization mechanism

NexusLS code should work through typed request, parameter, result, and protocol object classes. When a protocol value needs to exist, model it as an appropriate class with published properties.

Service and protocol logic should populate the object model. They should not bypass the model by manually assembling JSON payload trees.

Manual JSON construction inside NexusLS service, protocol, or request logic means the JSON-RPC object model has been bypassed.

## No Compatibility Bridges

Do not preserve old behavior by adding compatibility bridges, fallback paths, duplicate representations, transitional adapters, or dual object models.

When architecture changes, update the dependent code to use the corrected architecture directly.

Do not keep the old path alive.

## Review Standard

When reviewing NexusLS changes, verify that the code preserves the JSON-RPC object model:

- Request classes remain command objects.
- Result classes remain returnable result objects.
- Protocol structure is expressed through published properties.
- Services populate typed protocol objects instead of manually constructing wire payloads.
- Changes remove duplicate or bypass paths instead of adding new ones.
- No temporary bridge is introduced to avoid fixing dependent code.

If a change creates a second way to represent the same protocol value, it is probably wrong.
