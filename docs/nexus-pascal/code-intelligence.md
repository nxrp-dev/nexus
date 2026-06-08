# Nexus Pascal Code Intelligence

Nexus Pascal uses NexusLS to provide Pascal-aware editor features.

## Project-aware Unit Resolution

Pascal source files depend heavily on unit search paths. NexusLS uses selected
project context, toolchain configuration, and discovered source paths to locate
units.

This enables navigation for project units as well as system units such as
`SysUtils` when Free Pascal source paths are configured.

## Navigation

NexusLS supports common navigation workflows such as:

- go to definition
- unit click-through
- document and workspace symbols
- routine declaration to implementation switching
- routine implementation to declaration switching

The routine-pair navigation is Pascal-specific and follows the Delphi-style
workflow of moving between an interface declaration and implementation body.

## Completion

Completion is intended to combine syntax context, known units, symbols, and
project metadata.

As NexusLS grows, completion should become increasingly project-aware rather
than a generic list of words.

## Diagnostics

Diagnostics are produced from NexusLS parser and analysis behavior. The goal is
fast, useful feedback while editing, including incomplete or temporarily broken
source files.

NexusLS is designed to remain tolerant of editor-state code while still
improving its understanding of real Pascal syntax.

## Highlights And Symbols

Document symbols and highlights help navigate a unit without leaving the editor.
NexusLS is moving toward symbol-aware behavior rather than purely lexical
matching, especially for overloaded routines, parameters, locals, and class
members.
