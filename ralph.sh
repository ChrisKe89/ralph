#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude] [max_iterations]

set -e

# Completion sentinel (must appear as its own line)
SENTINEL="<promise>COMPLETE</promise>"

has_completion_sentinel() {
  # Normalize CRLF, trim whitespace, and require the sentinel to be the entire line.
  printf '%s\n' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -Fxq "$SENTINEL"
}

require_tool_on_path() {
  local tool_name="$1"
  local install_hint="$2"

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "Error: '$tool_name' not found on PATH."
    [ -n "$install_hint" ] && echo "$install_hint"
    exit 127
  fi
}

# Parse arguments
TOOL="amp"  # Default to amp for backwards compatibility
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "codex" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'codex'."
  exit 1
fi

# Ensure the selected tool binary exists before doing any work.
if [[ "$TOOL" == "amp" ]]; then
  require_tool_on_path "amp" "Install Amp and ensure 'amp' is on your PATH."
elif [[ "$TOOL" == "claude" ]]; then
  require_tool_on_path "claude" "Install Claude Code and ensure 'claude' is on your PATH."
else
  require_tool_on_path "codex" "Install Codex CLI and ensure 'codex' is on your PATH."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
RUN_LOG_DIR="$SCRIPT_DIR/.ralph"
mkdir -p "$RUN_LOG_DIR"
LAST_RUN_TRANSCRIPT="$RUN_LOG_DIR/last-run.transcript.log"
LAST_RUN_LAST_MESSAGE="$RUN_LOG_DIR/last-run.last-message.txt"
LAST_RUN_META="$RUN_LOG_DIR/last-run.meta.txt"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  RUN_STARTED_AT="$(date +"%Y-%m-%dT%H:%M:%S%z")"
  ITER_TRANSCRIPT="$RUN_LOG_DIR/iter-$i.transcript.log"
  ITER_LAST_MESSAGE="$RUN_LOG_DIR/iter-$i.last-message.txt"
  ITER_META="$RUN_LOG_DIR/iter-$i.meta.txt"

  : > "$ITER_TRANSCRIPT"
  : > "$ITER_LAST_MESSAGE"

  TOOL_EXIT=0
  OUTPUT=""

  # Run the selected tool with the ralph prompt and capture logs/output.
  if [[ "$TOOL" == "amp" ]]; then
    amp --dangerously-allow-all < "$SCRIPT_DIR/prompt.md" 2>&1 | tee "$ITER_TRANSCRIPT"
    TOOL_EXIT=${PIPESTATUS[0]}
    OUTPUT="$(cat "$ITER_TRANSCRIPT")"
    echo "command=amp --dangerously-allow-all < prompt.md" > "$ITER_META"
  elif [[ "$TOOL" == "claude" ]]; then
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee "$ITER_TRANSCRIPT"
    TOOL_EXIT=${PIPESTATUS[0]}
    OUTPUT="$(cat "$ITER_TRANSCRIPT")"
    echo "command=claude --dangerously-skip-permissions --print < CLAUDE.md" > "$ITER_META"
  else
    # Codex: write the final agent message to a file for strict completion detection.
    rm -f "$ITER_LAST_MESSAGE"
    codex exec --ask-for-approval never --sandbox danger-full-access --cd "$SCRIPT_DIR" \
      --output-last-message "$ITER_LAST_MESSAGE" < "$SCRIPT_DIR/CODEX.md" 2>&1 | tee "$ITER_TRANSCRIPT"
    TOOL_EXIT=${PIPESTATUS[0]}
    if [ -f "$ITER_LAST_MESSAGE" ]; then
      OUTPUT="$(cat "$ITER_LAST_MESSAGE")"
    else
      OUTPUT="$(cat "$ITER_TRANSCRIPT")"
    fi
    echo "command=codex exec --ask-for-approval never --sandbox danger-full-access --cd . --output-last-message <file> < CODEX.md" > "$ITER_META"
  fi

  {
    echo "started_at=$RUN_STARTED_AT"
    echo "tool=$TOOL"
    echo "iteration=$i"
    echo "exit_code=$TOOL_EXIT"
    echo "transcript_file=$ITER_TRANSCRIPT"
    echo "last_message_file=$ITER_LAST_MESSAGE"
  } >> "$ITER_META"

  cp "$ITER_TRANSCRIPT" "$LAST_RUN_TRANSCRIPT"
  cp "$ITER_META" "$LAST_RUN_META"
  if [ -f "$ITER_LAST_MESSAGE" ]; then
    cp "$ITER_LAST_MESSAGE" "$LAST_RUN_LAST_MESSAGE"
  else
    : > "$LAST_RUN_LAST_MESSAGE"
  fi

  if [ "$TOOL_EXIT" -ne 0 ]; then
    echo "Warning: '$TOOL' exited with code $TOOL_EXIT. Logs: $LAST_RUN_TRANSCRIPT"
  fi
  
  # Check for completion signal
  if has_completion_sentinel "$OUTPUT"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
