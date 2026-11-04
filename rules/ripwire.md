# Code Exploration Rules (ripwire)

## Environment (verified, don't re-check)
- ripwire 0.6.9 is installed at /usr/local/bin/ripwire. Don't run `which`, `--version` or `--help`.
- If a flag fails or behaves unexpectedly, use `ripwire --help=--FLAG` for that one flag.
- Output is compact XML, not prose. `p=` paths are relative to the `<dir>` you passed. `l=`/`e=` are start/end lines.
- Output is deterministic and cached, so re-running a query is cheap.

## Pass a module or package directory, not the repo root
On large repos (thousands of files per module) run ripwire on the module or package you are working in, not on `.`.
If you don't know which one, run `ripwire <repo-root> --tree --limit=20` once to see the top-level layout.

## Command cheat sheet
| Need | Command |
|---|---|
| Orient in a module/package | `ripwire <dir> --tree --limit=20` |
| Find code for a concept | `ripwire <dir> --for="<task>"` |
| Find usages of an identifier | `ripwire <dir> --grep=<Symbol> --limit=10` |
| Callers / callees / impact | `--callers=SYM`, `--callees=SYM`, `--impact=SYM` |
| Every place a symbol is used | `--uses=SYM` |
| Read one symbol's body | `--expand=<path>:<Symbol>` (the `next=` attribute gives this) |
| Signatures only (cheap) | `--for="<task>" --signatures-only` |
| What tests cover a change | `--affected=<file>` or `--situ` |
| Review a branch | `--map-diff`, `--pr-context` |

## Gotchas learned
- `--top-k` is ignored by `--for`. Use `--limit`/`--offset` on `--grep` and `--tree`, or `--token-budget=N`.
- `--tree` prints 80 files by default and includes test files. Add `--limit=N` and `--ignore-tests` / `--exclude=src/test`.
- `--for` with a vague word like "cache" returns `confidence="low"` (that word appears in nearly every file).
  Use a specific class or method name, or switch to `--grep`.
- `--for` already returns signatures with `next=` follow-ups. Follow `next=` with `--expand` instead of calling `read_file`.
- `--grep` returns each hit with its enclosing symbol, and `callers=0` can be a floor. Confirm with `--uses=SYM`.

## When read_file is allowed
- Files under ~30 lines.
- After ripwire has given a path and line range, and always with `range="start-end"`.

## Fall back to grep/glob when
- The target is non-code (`.adoc`, `.xml`, `.properties`) or ripwire reports it unindexed (`--skipped` explains why).
- You need a quick filename match. `glob` is fine for that.
