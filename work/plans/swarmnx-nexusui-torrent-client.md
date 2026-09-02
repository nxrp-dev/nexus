# Work Plan: SwarmNX NexusUI Torrent Client

## Inputs

- Source request: create a client in the new `C:\gitdev\nexus-lab\SwarmNX` folder that uses NexusUI for the front end.
- Related discussion:
  - SwarmNX should make use of the NexusNet BitTorrent library rather than reimplementing BitTorrent behavior.
  - NexusNet is the networking/library layer; `nexus-lab` is the application/lab surface.
  - Finished work-plan implementations should produce a source archive.
  - No commits or pushes.
  - Do not invent abbreviated class/unit prefixes or postfixes such as `SNX`/`TSNX` without approval.
  - Keep the product-facing UI focused on Load Torrent, Destination, Start, Pause, Stop, Status, Progress, and Log.
  - Put Verify Piece, Announce, Connect To Peer, peer host, and peer port under Diagnostics/Advanced rather than making them the main workflow.
- Existing constraints:
  - `C:\gitdev\nexus-lab\SwarmNX` currently exists as an empty sibling workspace folder, not under the `C:\gitdev\nexus` writable root.
  - NexusUI guidance applies to the UI shape: windows are first-class surfaces, controls are framework controls, and backend details should stay behind application objects where practical.
  - The current NexusNet torrent library exposes a useful library slice, but it is not yet a full autonomous torrent engine with piece scheduling, peer rotation, resume data, DHT, magnet links, or a production transfer loop.

## Summary

Build SwarmNX as a small NexusUI desktop client over the current NexusNet torrent library.

The first pass should be a real, usable shell for loading and inspecting a torrent session, preparing local files, verifying pieces, and exercising the current tracker/peer connection surfaces where the library already supports them. It should not pretend the library has a complete downloader scheduler yet.

The application should keep UI, application orchestration, and torrent-library ownership separate:

- NexusUI controls own rendering and input.
- A SwarmNX application-composition object owns high-level lifecycle and uses the global NexusUI `Application` object.
- `TSwarmTorrentController` owns the NexusNet torrent objects and translates UI commands into library calls.
- `TSwarmTorrentViewModel` exposes UI-friendly status fields and prevents controls from reaching into torrent internals.

## Verified Findings

- `C:\gitdev\nexus-lab\SwarmNX` exists and is currently empty.
- `C:\gitdev\nexus-lab\LifeStatNX` and `C:\gitdev\nexus-lab\SpaceTraderNX` also appear empty, so there is no populated lab-app template to copy.
- `NexusUI\example\LifeStatNXL.lpr` is the available NexusUI app reference. It creates controls directly, uses `TNXApplication`, `TNXWindow`, `TNXMainMenu`, `TNXToolbar`, `TNXTabControl`, `TNXGroupBox`, `TNXStatusBar`, and event-handler classes.
- `NexusNet\src\torrent\obNXTorrentSession.pas` currently provides:
  - session lifecycle: `Start`, `Pause`, `Stop`
  - file/piece surface: `WriteBlock`, `VerifyPiece`, `Status`
  - network surface: `AnnounceToTracker`, `ConnectToPeer`, `AcceptPeer`
  - ownership of `TNXTorrentMetaInfo`, `TNXTorrentPieceMap`, and `TNXTorrentFileStore`
- The current `TNXTorrentSession` status model includes name, info hash, total bytes, downloaded bytes, piece count, verified pieces, and session state.

## Architecture Problem

SwarmNX needs to be useful without turning the UI into the torrent engine.

The main risk is building a dashboard around behavior the library does not yet own. If the app starts with peer scheduling, piece selection, resume files, DHT, magnet links, or long-running transfer orchestration, the UI will either duplicate future NexusNet responsibilities or fake state.

The correct first step is a thin but honest client:

- load torrent metadata
- configure a destination root
- create and own a `TNXTorrentSession`
- show session status
- call existing library actions
- display errors and operation logs
- leave full downloader orchestration for a later NexusNet work plan

## Target Contract

- Owner:
  - `TSwarmClientApp` owns startup, shutdown, root window construction, and controller lifetime. It uses the existing NexusUI `Application: TNXApplication`; it does not descend from `TNXApplication`.
  - `TSwarmMainWindow` owns NexusUI controls and user interaction wiring.
  - `TSwarmTorrentController` owns the active `TNXTorrentSession` and loaded torrent objects.
  - `TSwarmTorrentViewModel` is the read-only UI projection of current torrent/session state.
- Responsibilities:
  - UI code may ask the controller to load, start, pause, stop, verify, announce, and connect.
  - UI code should not directly mutate `TNXTorrentSession`, `TNXTorrentFileStore`, or `TNXTorrentPieceMap`.
  - Controller methods should return clear success/failure information or raise controlled app-level exceptions that the main window can report.
  - Library exceptions should be caught at the app boundary and shown in the status/log surface.
- State flow:
  - User action -> `TSwarmMainWindow` event -> `TSwarmTorrentController` command -> NexusNet library -> refreshed `TSwarmTorrentViewModel` -> controls.
- Rendering/input/persistence behavior:
  - First pass uses ordinary NexusUI controls and a compact operational layout.
  - No persistent settings are required in the first pass unless a simple recent destination path can be added without extra infrastructure.
  - No background transfer worker is required in this first pass.

## Scope

- Scaffold `C:\gitdev\nexus-lab\SwarmNX` as a Free Pascal/NexusUI app.
- Add an app entry point and Lazarus project file if practical:
  - `SwarmNX.lpr`
  - `SwarmNX.lpi`
- Add source units:
  - `src\tpSwarmTypes.pas`
  - `src\obSwarmTorrentViewModel.pas`
  - `src\obSwarmTorrentController.pas`
  - `src\obSwarmMainWindow.pas`
  - `src\obSwarmClientApp.pas`
- Build first-screen UI:
  - primary client commands for opening a `.torrent`, selecting destination, start, pause, and stop
  - metadata panel: name, info hash, total size, piece count, piece length
  - status panel: state, verified pieces, downloaded/total bytes, percent
  - progress panel
  - log/status area for command results and errors
  - diagnostics panel for verify piece, tracker announce, peer host, peer port, and connect-to-peer actions
- Load `.torrent` files through `TNXTorrentMetaInfo.LoadFromFile`.
- Create a `TNXTorrentSession` with the selected destination root.
- Call `Start`, `Pause`, `Stop`, `VerifyPiece`, `AnnounceToTracker`, and `ConnectToPeer` only through the controller.
- Refresh the view model after every command.
- Use the project name `Swarm` for app-specific classes and units. Do not introduce abbreviated prefixes or postfixes without approval.

## Out Of Scope

- Full BitTorrent download orchestration.
- Piece picker UI.
- Peer scheduling, choking strategy, request windows, or background transfer loops.
- DHT, magnet links, peer exchange, encryption, resume files, UPnP/NAT traversal, and UDP trackers.
- Moving current library behavior out of NexusNet.
- Broad NexusUI framework changes.
- Committing or pushing.

## Staged Implementation Plan

### Stage 1: Project Skeleton

- Create the SwarmNX project and `src` folder.
- Reference NexusUI and NexusNet torrent units with explicit relative paths from `nexus-lab`.
- Add a minimal application object that starts NexusUI and owns the main window.
- Compile the empty shell before adding torrent behavior.

### Stage 2: Main Window Layout

- Create a dense operational NexusUI layout:
  - toolbar/menu for commands
  - left or top session setup panel
  - central torrent status fields
  - lower log/status area
- Keep controls owned by the main window object.
- Avoid landing-page or marketing-style UI.

### Stage 3: Torrent Controller

- Implement `TSwarmTorrentController`.
- Add explicit methods:
  - `LoadTorrent`
  - `SetDestinationRoot`
  - `StartSession`
  - `PauseSession`
  - `StopSession`
  - `VerifyPiece`
  - `Announce`
  - `ConnectToPeer`
  - `BuildViewModel`
- Keep exception handling at the UI boundary.
- Keep NexusNet object ownership centralized in the controller.

### Stage 4: UI Binding

- Wire buttons/menu items to controller commands.
- Update labels/progress/status after each command.
- Log meaningful success/failure messages.
- Disable commands that do not make sense before a torrent and destination are selected.

### Stage 5: Verification And Archive

- Compile the SwarmNX app.
- Run the executable if practical in this environment.
- Re-run NexusNet torrent tests if controller changes expose library integration issues.
- Produce a separate SwarmNX lab source/runtime archive after implementation completes.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

Compile SwarmNX with explicit unit paths. The exact command should be confirmed after the project skeleton exists, but the expected shape is:

```text
fpc -Fu..\nexus\NexusUI -Fu..\nexus\NexusNet\src\torrent -Fu..\nexus\lib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\SwarmNX\units -FEoutput\SwarmNX\bin C:\gitdev\nexus-lab\SwarmNX\SwarmNX.lpr
```

Run if compile succeeds:

```text
C:\gitdev\nexus-lab\SwarmNX\output\SwarmNX\bin\SwarmNX.exe
```

Re-run NexusNet torrent tests if any integration issue suggests library behavior may have been affected:

```text
fpc -FuNexusNet\src\torrent -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetTorrentTests\units -FEoutput\NexusNetTorrentTests\bin NexusNet\tests\NexusNetTorrentTests.lpr
output\NexusNetTorrentTests\bin\NexusNetTorrentTests.exe
```

Archive after implementation:

```text
Create a separate swarmnx-lab-source-<timestamp>.zip from C:\gitdev\nexus-lab\SwarmNX, excluding output and compiled artifacts.
```

## Risks And Questions

- `SwarmNX` lives outside the current writable root. Implementation will need either writable-root coverage or approved escalated writes.
- The current NexusNet session is still a library facade. The UI should expose current capabilities honestly and leave full transfer automation for a future NexusNet work plan.
- The exact NexusUI compile paths may need adjustment after the project file exists.
- The archive question is resolved for this pass by producing a separate SwarmNX lab archive rather than expanding the Nexus source archive across a sibling repo.

## Approval Gate

No implementation begins until Kevin explicitly authorizes this SwarmNX work plan.
