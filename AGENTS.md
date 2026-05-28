# Nexus Repository Agent Instructions

These rules apply to the whole repository.

## AI Review Issue Labeling

- Any GitHub issue created by ChatGPT must include the label `nxrp-review-bot`.
- Treat issues labeled `nxrp-review-bot` as external AI review notes: useful input, but verify claims against the codebase before acting on them.

## Local Notifications

- When a task completes or user input is needed, run `scripts\Notify-Codex.ps1` with a spoken sentence.
