---
name: review-fix
description: Review the changes on the current branch (relative to its base branch), fix the problems found, and log every finding and fix in Logseq format via logseq-tracker as you go. Use when the user asks to "review and fix" the branch, PR or current changes. For a read-only review use review-only instead.
---

Review the changes this branch adds, **fix** what you find, and record each finding and its resolution in a Logseq-format log with `logseq-tracker` as you go.

## 1. Pin the changes under review

Use the base the user gave. Otherwise use the branch's merge-base with the default branch:

```
base=$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD main || git merge-base HEAD master)
git diff "$base"...HEAD --stat
git log "$base"..HEAD --oneline
```

Also include uncommitted work (`git status --short`, `git diff HEAD`). If there is nothing to review, say so and stop. Do not start a log.

## 2. Start the log

Use the current branch name as `--ref`, and `review-fix` as the action:

```
logseq-tracker init --ref "<BRANCH>" --action review-fix --repo "<OWNER/REPO or directory name>" --title "Review and fix <BRANCH>"
```

If `logseq-tracker` is missing, say so and carry on without logging.

## 3. Review and fix

Go through the diff file by file. Look for: bugs and logic errors, unhandled errors and edge cases, resource leaks, concurrency problems, security issues (injection, secrets, unsafe input), broken or missing tests, and violations of documented repo standards (`CONTRIBUTING.md`, `CODING_STANDARDS.md`, etc.). Only review lines this branch changed (and what they directly affect). Do not review or refactor unrelated code.

For **each** problem, as soon as you find it:

1. Record it, with `path:line` first:
   `logseq-tracker update --ref "<BRANCH>" --action review-fix --finding "path/file.ext:42 <what is wrong and why>" --severity <high|medium|low|info>`
   The command prints `Added finding #N`.
2. If the fix is clear and safe, make the minimal fix, then mark it done and record the file:
   `logseq-tracker update --ref "<BRANCH>" --action review-fix --resolve N --file "path/file.ext"`
3. If it needs a decision, a bigger refactor, or is only a judgement call, **leave it unresolved** (it stays `TODO` in the log) and do not change code.

Add a short running synopsis now and then:
`logseq-tracker update --ref "<BRANCH>" --action review-fix --synopsis "Reviewed 3 of 7 files; 2 fixed"`

Keep fixes small and in the existing style. Do not commit unless the user asked.

## 4. Verify

Run the project's relevant build/tests/lint for the files you changed. If they fail because of your fixes, repair them or revert that fix and mark the finding as unresolved by noting it in the synopsis.

## 5. Finish the log and report

```
logseq-tracker finish --ref "<BRANCH>" --action review-fix --status completed --synopsis "<findings found / fixed / left open>" --verify "<test command and result>" --branch "<BRANCH>"
```

Use `--status failed` with the reason if the review could not be completed.

Then print the final log with `logseq-tracker show --ref "<BRANCH>" --action review-fix` and summarize for the user: what was fixed, what is still open and why, and the log file path.
