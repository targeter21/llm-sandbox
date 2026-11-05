#!/usr/bin/env bash
# install.sh - Install llm-sandbox for the current user.
#
#   - copies bin/, images/, share/ and the justfile to $INSTALL_DIR
#   - symlinks the launcher scripts into $BIN_DIR
#   - copies the shared rules/ and skills/ into the config directory of each
#     agent ($BOB_DIR, $CLAUDE_DIR, $GEMINI_DIR). Files with the same name are
#     overwritten, other files are left alone. claude-sandbox and gemini-sandbox
#     compile the rules into CLAUDE.md / GEMINI.md when they start.
#   - installs and enables a systemd *user* service that prunes sandbox caches
#     (via common-sandbox) and rebuilds the container images at login/startup
#
# Usage: ./install.sh [--uninstall] [--no-service]
#
# Overridable environment variables:
#   INSTALL_DIR  default: ${XDG_DATA_HOME:-$HOME/.local/share}/llm-sandbox
#   BIN_DIR      default: $HOME/.local/bin
#   UNIT_DIR     default: ${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
#   BOB_DIR      default: $HOME/.bob
#   CLAUDE_DIR   default: $HOME/.claude
#   GEMINI_DIR   default: $HOME/.gemini
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/llm-sandbox}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
UNIT_DIR="${UNIT_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"
BOB_DIR="${BOB_DIR:-$HOME/.bob}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
GEMINI_DIR="${GEMINI_DIR:-$HOME/.gemini}"
SERVICE_NAME="llm-sandbox-update.service"

# command name -> script in bin/
LINKS=(
    "bob-sandbox:bob-sandbox"
    "claude-sandbox:claude-sandbox"
    "gemini-sandbox:gemini-sandbox"
    "common-sandbox:common-sandbox.sh"
)

# Agent config directories that receive the shared rules/ and skills/
AGENT_DIRS=("$BOB_DIR" "$CLAUDE_DIR" "$GEMINI_DIR")

UNINSTALL=false
INSTALL_SERVICE=true
for arg in "$@"; do
    case "$arg" in
        --uninstall)  UNINSTALL=true ;;
        --no-service) INSTALL_SERVICE=false ;;
        -h|--help)
            sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

have_systemd_user() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

uninstall() {
    echo "Uninstalling llm-sandbox..."
    if have_systemd_user; then
        systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null || true
    fi
    rm -f "$UNIT_DIR/$SERVICE_NAME"
    have_systemd_user && systemctl --user daemon-reload || true

    local entry
    for entry in "${LINKS[@]}"; do
        local link="$BIN_DIR/${entry%%:*}"
        # Only remove symlinks that point into our install dir
        if [ -L "$link" ] && [[ "$(readlink "$link")" == "$INSTALL_DIR"/* ]]; then
            rm -f "$link"
        fi
    done
    rm -rf "$INSTALL_DIR"

    # Remove only the rules/skills that this repo provides
    local agent_dir item
    for agent_dir in "${AGENT_DIRS[@]}"; do
        for item in "$REPO_DIR"/rules/*; do
            [ -e "$item" ] && rm -f "${agent_dir:?}/rules/$(basename "$item")"
        done
        for item in "$REPO_DIR"/skills/*; do
            [ -e "$item" ] && rm -rf "${agent_dir:?}/skills/$(basename "$item")"
        done
    done
    echo "Done."
}

install() {
    local missing=()
    local dep
    for dep in podman git; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "ERROR: missing required dependencies: ${missing[*]}" >&2
        exit 1
    fi

    echo "Installing files to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR" "$BIN_DIR"
    rm -rf "${INSTALL_DIR:?}/bin" "${INSTALL_DIR:?}/images" "${INSTALL_DIR:?}/share"
    cp -R "$REPO_DIR/bin" "$REPO_DIR/images" "$REPO_DIR/share" "$INSTALL_DIR/"
    cp "$REPO_DIR/justfile" "$INSTALL_DIR/justfile"
    chmod +x "$INSTALL_DIR"/bin/* "$INSTALL_DIR"/share/claude-setup "$INSTALL_DIR"/share/bob-prompt

    echo "Linking commands into $BIN_DIR..."
    local entry
    for entry in "${LINKS[@]}"; do
        ln -sfn "$INSTALL_DIR/bin/${entry#*:}" "$BIN_DIR/${entry%%:*}"
        echo "  ${entry%%:*} -> $INSTALL_DIR/bin/${entry#*:}"
    done
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo "NOTE: $BIN_DIR is not in your PATH." ;;
    esac

    # Real copies (not symlinks): the agent config dirs are bind-mounted into
    # containers, where a symlink into $INSTALL_DIR/$REPO_DIR would dangle.
    local agent_dir
    for agent_dir in "${AGENT_DIRS[@]}"; do
        echo "Installing rules and skills to $agent_dir..."
        mkdir -p "$agent_dir/rules" "$agent_dir/skills"
        cp -R "$REPO_DIR/rules/." "$agent_dir/rules/"
        cp -R "$REPO_DIR/skills/." "$agent_dir/skills/"
    done

    if [ "$INSTALL_SERVICE" = false ]; then
        echo "Skipping systemd service (--no-service)."
        return
    fi

    local just_bin
    just_bin="$(command -v just || true)"
    if [ -z "$just_bin" ]; then
        echo "WARNING: 'just' not found; skipping startup service. Install just and re-run." >&2
        return
    fi
    if ! have_systemd_user; then
        echo "WARNING: systemd user session not available; skipping startup service." >&2
        echo "         You can update images manually with: just --justfile $INSTALL_DIR/justfile update-agent-sandbox" >&2
        return
    fi

    echo "Installing systemd user service to $UNIT_DIR/$SERVICE_NAME..."
    mkdir -p "$UNIT_DIR"
    sed -e "s|@JUST@|$just_bin|g" \
        -e "s|@INSTALL_DIR@|$INSTALL_DIR|g" \
        "$REPO_DIR/systemd/$SERVICE_NAME.in" > "$UNIT_DIR/$SERVICE_NAME"
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    echo "Service enabled. Run now with: systemctl --user start $SERVICE_NAME"
}

if [ "$UNINSTALL" = true ]; then
    uninstall
else
    install
fi
