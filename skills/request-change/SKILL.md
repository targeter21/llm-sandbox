---
name: request-change
description: Capture a code change the user wants (a new feature, a behavior change, a refactor) as a Logseq TODO via logseq-tracker, then ask whether to implement it now or only log it. Use when the user says things like "I want X to behave like Y", "we should add...", "log a change request", or notices something to change while working on something else.
---

Turn an idea for a code change into a Logseq `TODO` task that a later session can pick up, then ask the user whether to implement it now or only log it. The log entry is the deliverable either way.

## 1. Understand the request

You need two things from the user. Ask for whatever is missing in one short message; don't guess:

- **Desired behavior**: what should be true after the change.
- **Acceptance**: an observable check (a test to add, a command to run, a behavior to see).

Everything else you work out yourself.

## 2. Look at the code (read-only)

Find where the change would go and what happens today. Use `ripwire` (see the ripwire rule) or grep. Do **not** edit anything in this step. Collect:

- **Current behavior**, with `path:line` references.
- **Where**: the files and symbols involved.
- **Base**: `git rev-parse --abbrev-ref HEAD` and `git rev-parse --short HEAD`, written as `branch@sha`. The references are only true against that commit.

If the request is unclear or looks wrong after reading the code, say so and ask before logging.

## 3. Log it

Pick a short kebab-case label for `--ref` (for example `cache-ttl-config`). Use the `owner/repo` name (`gh repo view --json nameWithOwner -q .nameWithOwner`, or the directory name if that fails).

```
logseq-tracker request --ref "<LABEL>" --repo "<OWNER/REPO>" --title "<SHORT TITLE>" \
  --desired "<desired behavior>" --current "<current behavior, path:line>" \
  --where "<files and symbols>" --acceptance "<how to tell it is done>" --base "<branch@sha>"
```

This writes an open `TODO ... #agent-request` block. If `logseq-tracker` is missing, say so and print the block by hand in the same shape instead.

## 4. Ask: fix now or just log?

Unless the user already said which (for example "just log it" or "go ahead and do it"), ask exactly this and wait for the answer:

> Logged as `<LABEL>`. Do you want me to implement it now, or leave it logged for later?

### Log only

Stop. Do not change any project files. Reply with the log path from `logseq-tracker` and a one-line summary of the request.

### Implement now

1. Record that work has started and keep adding the files you touch:
   `logseq-tracker update --ref "<LABEL>" --action change-request --synopsis "Implementing" --file "<path>"`
2. Make the **minimal** change that meets the desired behavior and acceptance. Don't widen the scope or refactor unrelated code. Follow the repo's existing style, and add or update tests for the acceptance check.
3. Run the relevant build and tests.
4. Close the entry (it turns the block into `DONE`):
   `logseq-tracker finish --ref "<LABEL>" --action change-request --status completed --synopsis "<what was changed>" --verify "<test command and result>" --branch "<BRANCH>"`
   If it could not be finished, use `--status failed` with the reason. The block stays `TODO` and the reason is recorded.
5. Don't commit unless the user asked. Summarize what changed, the test result, and the log path.

## Notes

- One request per invocation. If the user lists several, log each separately, then ask once about the whole batch.
- The log is copied into the user's Logseq journal when the sandbox session ends.
