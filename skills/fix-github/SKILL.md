---
name: fix-github
description: Investigate a GitHub issue, fix the bug, and keep a Logseq-format run log via logseq-tracker. Use when the user asks to fix, resolve or work on a GitHub issue by number or URL.
---

Investigate a GitHub issue, fix it, and keep the run log up to date in Logseq format with `logseq-tracker`.

## Logging protocol

Run `logseq-tracker` (on `PATH` in the sandbox) from your shell tool at these points. Use the action name `fix-github` every time. If the command is missing, say so and continue without logging.

1. **At task start:**
   `logseq-tracker init --issue <ISSUE_NUMBER> --action fix-github --repo <OWNER/REPO> --title "<ISSUE_TITLE>"`

2. **While investigating or editing** (after finding the root cause, and after each file you edit):
   `logseq-tracker update --issue <ISSUE_NUMBER> --action fix-github --synopsis "Found root cause in module X" --file "path/to/edited/file"`

3. **On completion, before your final message:**
   `logseq-tracker finish --issue <ISSUE_NUMBER> --action fix-github --status completed --synopsis "<2-SENTENCE_EXPLANATION_OF_FIX>" --verify "<TEST_COMMAND_AND_RESULT>" --branch "<BRANCH_NAME>"`

   If the fix failed or tests could not pass:
   `logseq-tracker finish --issue <ISSUE_NUMBER> --action fix-github --status failed --synopsis "<REASON_FOR_FAILURE>"`

## Workflow

1. Initialize the log.
2. Read the issue (`gh issue view <ISSUE_NUMBER>`) and find the repository name (`gh repo view --json nameWithOwner -q .nameWithOwner`).
3. Locate the bug, edit the code, run the relevant tests.
4. Finish the log.
5. Summarize for the user, including the log path that `logseq-tracker` printed.
