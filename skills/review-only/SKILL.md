---
name: review-only
description: Review the changes on the current branch (relative to its base branch) without modifying any code, and output the findings as a Logseq-format log via logseq-tracker for later tracking. Use when the user asks for a review, audit or findings list only, with no fixes.
---

Review the changes this branch adds and output the findings as a Logseq-format log with `logseq-tracker`. **Do not modify any project files.** Fixing is the job of `review-fix`.

## 1. Pin the changes under review

Use the base the user gave. Otherwise use the branch's merge-base with the default branch:

```
base=$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD main || git merge-base HEAD master)
git diff "$base"...HEAD --stat
git log "$base"..HEAD --oneline
```

Also include uncommitted work (`git status --short`, `git diff HEAD`). If there is nothing to review, say so and stop. Do not start a log.

## 2. Start the log

Use the current branch name as `--ref`, and `review-only` as the action:

```
logseq-tracker init --ref "<BRANCH>" --action review-only --repo "<OWNER/REPO or directory name>" --title "Review of <BRANCH>"
```

If `logseq-tracker` is missing, say so, and print the findings in the same Logseq format by hand (see step 4).

## 3. Review

Go through the diff file by file. Look for: bugs and logic errors, unhandled errors and edge cases, resource leaks, concurrency problems, security issues (injection, secrets, unsafe input), broken or missing tests, and violations of documented repo standards (`CONTRIBUTING.md`, `CODING_STANDARDS.md`, etc.). Only review lines this branch changed (and what they directly affect).

For each problem, record it right away, with `path:line` first and a short reason and suggested fix:

`logseq-tracker update --ref "<BRANCH>" --action review-only --finding "path/file.ext:42 <what is wrong, why, suggested fix>" --severity <high|medium|low|info>`

Running tests or linters to confirm a suspicion is fine, as long as they do not change tracked files.

## 4. Finish and output the log

```
logseq-tracker finish --ref "<BRANCH>" --action review-only --status completed --synopsis "<N findings: x high, y medium, z low>"
logseq-tracker show --ref "<BRANCH>" --action review-only
```

Use `--status failed` with the reason if the review could not be completed.

Print the output of `show` to the user as-is, in a markdown code block, so it can be pasted into Logseq, and give the saved log file path. Every finding appears as a `TODO` block. Add a two-line summary after it. Do not make any code changes.
