# llm-sandbox

Run LLM coding agents ([IBM Bob](https://bob.ibm.com), [Claude Code](https://claude.com/claude-code),
[Gemini CLI](https://github.com/google-gemini/gemini-cli)) in **ephemeral Podman containers**, each working in its
own throw-away **git worktree**. When the session ends you choose whether to merge the agent's commits back,
keep the branch, or discard everything.

> **These scripts are opinionated.** They reflect one developer's workflow, not a general-purpose framework.
> Read [Opinionated defaults](#opinionated-defaults) before installing, and fork/edit the Dockerfiles and
> launchers to suit your own setup.

## How it works

```
fedora:latest
   └── agent-base-sandbox   (JDK, Maven, Node, git, gh, podman, ripwire)
          ├── bob-dev-sandbox
          ├── claude-dev-sandbox
          └── gemini-dev-sandbox
```

- `bob-sandbox`, `claude-sandbox`, `gemini-sandbox` – launchers. Each creates a worktree of the current git
  repository on a temporary branch, starts the matching container, and on exit offers to merge the result.
- `common-sandbox` – shared engine (worktrees, container flags, cleanup). The launchers source it; it can also be
  run directly for maintenance: `common-sandbox --prune` or `common-sandbox --clean`.
- A systemd **user** service runs at startup, calls `common-sandbox --prune` and rebuilds all images via `just`.

## Repository layout

```
bin/        launcher scripts and common-sandbox.sh
images/     Dockerfiles for the base image and each agent image
rules/      default agent rules, installed for all three agents
skills/     default agent skills, installed for all three agents
share/      helper files mounted into containers (claude-setup)
systemd/    service unit template
justfile    image build / startup recipes
install.sh  installer
```

## Requirements

- A Linux host with `podman` and `git`, and GNU coreutils (the scripts use `readlink -m` and `chmod --reference`, so
  macOS/BSD are not supported). The containers themselves are Fedora-based, whatever your host distro, and the
  images build for x86_64 or aarch64.
- [`just`](https://github.com/casey/just) and systemd (only for the automatic image update service)
- `gh` (optional, its token is forwarded into containers)

## Install

```bash
./install.sh              # install files, symlinks and the systemd user service
./install.sh --no-service # skip the systemd service
./install.sh --uninstall  # remove everything the installer created
```

By default:

- files are copied to `~/.local/share/llm-sandbox`
- commands are symlinked into `~/.local/bin`
- `rules/` and `skills/` are copied into `~/.bob`, `~/.claude` and `~/.gemini` (under `rules/` and `skills/`)
- the unit is written to `~/.config/systemd/user/llm-sandbox-update.service`

Override with `INSTALL_DIR`, `BIN_DIR`, `UNIT_DIR`, `BOB_DIR`, `CLAUDE_DIR` and `GEMINI_DIR`.

Build the images for the first time (or trigger an update at any time):

```bash
systemctl --user start llm-sandbox-update.service
# or
just --justfile ~/.local/share/llm-sandbox/justfile update-agent-sandbox
```

To start the service even when you are not logged in, run `loginctl enable-linger $USER`.

## Usage

Run from inside any git repository:

```bash
bob-sandbox
claude-sandbox
gemini-sandbox
```

Maintenance (same flags on every launcher and on `common-sandbox`):

```bash
common-sandbox --prune   # delete cache files older than 14 days
common-sandbox --clean   # wipe all sandbox state and worktrees
```

## Opinionated defaults

- **Ripwire is installed in every image.** The base image downloads
  [ripwire](https://github.com/redhat-et/ripwire) (pinned to v0.6.9) into `/usr/local/bin`, and the default
  rule `rules/ripwire.md` tells the agent to use it for code exploration. If you don't want it, remove the
  install step from `images/Dockerfile.agent-base` and delete `rules/ripwire.md` before installing.
- **Default rules and skills are installed for all three agents** (see below).
- **Agents run with their safety prompts off**: Claude is started with `--dangerously-skip-permissions` and
  Gemini with `--approval-mode=yolo`. The container and throw-away worktree are the safety boundary.
- **Containers use host networking** (`--network host`), run as root, and receive your `gh` token as `GH_TOKEN`
  when `gh auth token` works. Your host `~/.config/gh` is not mounted or copied, so `gh` settings such as aliases
  are not available in the container.
- **The toolchain is Java-centric**: Fedora base image with the latest OpenJDK, Maven, Node.js/npm, git, gh and
  podman, plus a Maven cache shared between sessions.
- **Uncommitted work is auto-committed** in the worktree when a session ends, before you are asked whether to
  merge, keep or discard the branch.
- **Images are rebuilt at every startup** by the systemd user service, which also installs the latest Bob,
  Claude Code and Gemini CLI at that time.

### Default rules and skills

Provided in [`rules/`](rules/) and [`skills/`](skills/) and copied by `install.sh` into each agent's config
directory:

| Path | Purpose |
|---|---|
| `rules/ripwire.md` | Tells the agent to explore code with `ripwire` instead of reading whole files |
| `skills/code-review/` | Review a branch/PR against repo coding standards and the originating spec |
| `skills/grill-me/` | Stress-test a plan or decision by questioning the user |

### What the containers see

Each session gets its own home directory (`$BASE_SANDBOX_DIR/sessions/<agent>_<id>`) mounted as `/root`. The host's
agent directories (`~/.bob`, `~/.claude`, `~/.gemini`) are **never mounted**. Instead, the launcher copies a small
allow-list of files into the session home before the container starts, and the agent works on those copies. History,
logs, caches and any other changes the agent makes stay in the session home, so concurrent sessions never share a
live file and nothing can modify your host config directly.

| Agent | Authentication | Copied in (discarded on exit) | Generated per session |
|---|---|---|---|
| Bob | Login saved in `~/.bob/settings/auth-secrets.json` (created or updated on exit, **synced back**) | `~/.bob/{rules,skills}`, `~/.bob/settings/settings.json` | – |
| Claude | Vertex AI via gcloud (cache in `$BASE_SANDBOX_DIR/shared_gcloud`, see below) | `~/.claude/{settings.json,skills,CLAUDE.md}`, `~/.claude.json` | `~/.claude/CLAUDE.md` from `rules/` |
| Gemini | `GEMINI_API_KEY` environment variable | `~/.gemini/{settings.json,.env,skills,policies,GEMINI.md}` | `~/.gemini/GEMINI.md` from `rules/` |

Files that don't exist on the host are skipped.

#### Authentication

All three images are always built, whatever credentials you have: the `just` recipe and the startup service never
check `CLAUDE_VERTEX_PROJECT_ID`, `GEMINI_API_KEY` or `auth-secrets.json`. These only matter when you launch an
agent. To skip an agent you don't use, remove its `podman build` line from the `justfile`.

Only these three authentication setups are supported out of the box. Other modes (Claude or Gemini OAuth/browser
logins, other Bob auth methods, ...) are not wired up; adapt the launchers if you use them.

- **Bob:** `auth-secrets.json` is copied into the session if it exists, and `bob-sandbox` starts either way. If it
  doesn't exist yet, log in at Bob's prompt. When the session ends, the exit trap (`_sync_auth_back` in
  `bin/common-sandbox.sh`) writes the file back to the host if Bob created or changed it (a first login or a token
  refresh), creating `~/.bob/settings` if needed. Unchanged files are left alone. The write is atomic and keeps the
  file's permissions (new files get `600`) and symlinks. If the host copy also changed during the session (another
  sandbox refreshed it), the newer file wins and a warning is printed when the host's is kept. Syncing runs on a
  normal exit, Ctrl-C and `SIGTERM`, but not if the launcher is killed with `SIGKILL`, in which case that
  session's login is lost.
- **Claude:** authenticates to Vertex AI with gcloud Application Default Credentials (ADC). Set your Google Cloud
  project ID in `CLAUDE_VERTEX_PROJECT_ID` on the host before launching (see [Setting the Vertex project](#setting-the-vertex-project)).
  The credentials live in `$BASE_SANDBOX_DIR/shared_gcloud` (mounted read-write, **not** your host's
  `~/.config/gcloud`), so you only log in once across all sandboxes. `ANTHROPIC_API_KEY` is not forwarded.
  `common-sandbox --clean` deletes the gcloud cache, and `--prune` deletes files in it that haven't been accessed for
  14 days.
- **Gemini:** export `GEMINI_API_KEY` on the host; it is forwarded into every container. If it is unset, nothing is
  forwarded and `gemini-sandbox` still starts without a warning, so Gemini will have no API key. Nothing else needs
  to persist. `settings.json` (which selects the API-key login method) is copied in, but changes made to it inside
  a sandbox are discarded.

##### Setting the Vertex project

```bash
export CLAUDE_VERTEX_PROJECT_ID=my-gcp-project   # add to ~/.bashrc / ~/.zshrc to make it permanent
claude-sandbox
```

`claude-sandbox` forwards the variable into the container, where it *sources* [`share/claude-setup`](share/claude-setup)
with that project ID before starting Claude. The script is only about gcloud and Vertex AI (about 60 lines). It:

- exports `CLAUDE_CODE_USE_VERTEX=1`, `CLOUD_ML_REGION=global` and `ANTHROPIC_VERTEX_PROJECT_ID=<project>` for that
  session only. It does not write shell rc files or any env file;
- reuses the cached ADC login if it is still valid. Otherwise it runs
  `gcloud auth application-default login --no-launch-browser`, which prints a URL to open in your host browser and
  asks for the verification code;
- sets the ADC quota project to the same project ID.

If the login or the quota project can't be set up (for example you lack access to the project), the script prints the
error and `claude-sandbox` exits instead of starting Claude. If `CLAUDE_VERTEX_PROJECT_ID` is unset, `claude-setup`
is skipped: Claude still starts, but no gcloud login is attempted and it only has whatever your copied
`~/.claude/settings.json` provides. That file may already contain the `CLAUDE_CODE_USE_VERTEX` /
`ANTHROPIC_VERTEX_PROJECT_ID` environment values, but it does not create the gcloud login. If your `settings.json`
sets a different project than `CLAUDE_VERTEX_PROJECT_ID`, keep the two consistent.

To persist another file a tool writes at login, copy it in with `seed_auth_from_host` instead of `seed_from_host`
in the matching launcher; it is then synced back on exit (and may be absent on the host the first time).

Still shared with the host (bind-mounted read-write): the shared Maven cache (`~/.m2/repository`, all three) and
Claude's gcloud cache described above.

Claude and Gemini have no rules directory of their own, only a single context file. So `claude-sandbox` and
`gemini-sandbox` concatenate every `*.md` and `*.txt` file in the host's `~/.claude/rules` / `~/.gemini/rules`
into `CLAUDE.md` / `GEMINI.md` inside the session home on each launch (see `compile_rules`). The host's own
`CLAUDE.md` / `GEMINI.md` is never modified; the copy is kept as-is when there are no rule files. Skills are plain
`SKILL.md` directories that rely on each tool's own skill discovery; the launchers do not process them.

Notes:

- `install.sh` still writes to the host: it copies `rules/` and `skills/` into `~/.bob`, `~/.claude` and
  `~/.gemini`, so host-side runs of those tools pick them up too. The launchers never write to those directories.
- Re-running `install.sh` overwrites files with the same name; other files you keep in those directories are
  left alone. `--uninstall` removes only the rules and skills that this repo provides.
- If you prefer to maintain a single rules directory yourself, you can replace `~/.claude/rules` or
  `~/.gemini/rules` with a symlink to it (e.g. `ln -s ~/.bob/rules ~/.claude/rules`). Compilation happens on the
  host before the container starts and symlinks are followed when copying, so this works. The installer will then
  write into the symlink target.
- The default skills were written for Bob; `code-review`, for example, expects to spawn parallel sub-agents, which
  other tools may support differently.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `BASE_SANDBOX_DIR` | `~/.local/share/llm_sandbox_homes` | Session homes, worktrees, shared Maven/gcloud caches |
| `GEMINI_API_KEY` | – | Gemini authentication; forwarded to the Gemini container |
| `CLAUDE_VERTEX_PROJECT_ID` | – | Claude authentication: Google Cloud project ID for Vertex AI. See [Setting the Vertex project](#setting-the-vertex-project) |

Bob needs no environment variable: log in at its prompt on first run and `~/.bob/settings/auth-secrets.json` is
saved on exit. See [What the containers see](#what-the-containers-see) for everything else that is read from the host.
