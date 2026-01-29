- [x] Task - Add `codex` as a supported tool option in `ralph.sh`
  **Acceptance Criteria**

  * Running `./ralph.sh --tool codex` does not error on “unknown tool”
  * Help/usage text (if present) mentions `codex` alongside existing tools
  * Invalid tool values still fail with a clear error message

- [x] Task - Implement a Codex execution path in `ralph.sh` using non-interactive Codex CLI
  **Acceptance Criteria**

  * When `--tool codex` is selected, the script runs Codex via `codex exec` (non-interactive) and captures the final output into the same variable/flow used by other tools
  * The Codex run is configured to allow repo edits and running commands (e.g., uses `--full-auto` or an equivalent documented flag)
  * Failure to run Codex (non-zero exit) is handled and surfaced clearly (and the loop behavior matches existing tool behavior)

- [x] Task - Add a Codex prompt template file (e.g., `CODEX.md`) aligned with Ralph’s loop contract
  **Acceptance Criteria**

  * The prompt instructs Codex to: pick the next failing - [ ] Task/story, implement changes, run required commands, update tracking files, and only then emit the completion sentinel
  * The prompt explicitly requires the exact completion sentinel string (see next - [ ] Task)
  * The prompt includes “don’t modify these files” guidance if your repo needs it (e.g., don’t change the runner script, don’t rewrite PRD structure)

- [x] Task - Make completion detection strict and consistent across tools
  **Acceptance Criteria**

  * `ralph.sh` checks for an exact sentinel (e.g., `<promise>COMPLETE</promise>`) rather than a loose “COMPLETE” substring
  * The Codex prompt template guarantees it outputs the exact sentinel only when all required - [ ] Tasks are complete
  * Existing tool prompts/templates are updated (if needed) so they still emit the exact sentinel and don’t break the loop

- [x] Task - Add tool availability checks for Codex (and optionally other tools) before starting the loop
  **Acceptance Criteria**

  * If `--tool codex` is selected and `codex` is not on `PATH`, the script exits early with a clear install/setup message
  * The script does not begin iterations if the selected tool binary is missing

- [x] Task - Ensure Codex output capture/logging works reliably (stdout/stderr, transcripts)
  **Acceptance Criteria**

  * The script captures the final Codex response used for completion detection
  * The script preserves useful logs for debugging (either via `tee` to a file or a dedicated “last run output” file)
  * A failed iteration records enough information to reproduce the issue

- [x] Task - Update README with Codex setup and usage instructions
  **Acceptance Criteria**

  * README includes Codex CLI installation steps and prerequisites
  * README includes an example command for running Ralph with Codex
  * README documents any required environment variables/config (especially for CI usage) and any recommended permission mode

- [x] Task - Add a lightweight “smoke test” workflow or documented manual test plan for Codex mode
  **Acceptance Criteria**

  * There is a repeatable way to verify the `--tool codex` path works end-to-end (one small - [ ] Task, one iteration)
  * The test plan includes how to confirm: prompt is loaded, Codex runs, sentinel detection works, and progress tracking updates as expected
