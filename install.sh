#!/bin/sh
# Determinagents installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iansherr/determinagents/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/iansherr/determinagents/dev/install.sh  | sh -s -- --branch=dev
#
# Honors:
#   $DETERMINAGENTS_HOME — install path (default: ~/.determinagents)
#   $DETERMINAGENTS_BIN  — shim install path (default: ~/.local/bin)

set -eu

# Detect if running from a local clone
IN_REPO=false
if [ -f "bin/determinagents" ] && [ -d ".git" ]; then
  IN_REPO=true
fi
FORCE_UPDATE=false

REPO_URL="${DETERMINAGENTS_REPO_URL:-https://github.com/iansherr/determinagents.git}"
INSTALL_DIR="${DETERMINAGENTS_HOME:-$HOME/.determinagents}"
BIN_DIR="${DETERMINAGENTS_BIN:-$HOME/.local/bin}"
BRANCH="main"

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --branch=*) BRANCH="${arg#--branch=}" ;;
    --dir=*)    INSTALL_DIR="${arg#--dir=}" ;;
    --bin=*)    BIN_DIR="${arg#--bin=}" ;;
    --help|-h)
      cat <<HELP
Determinagents installer

  --branch=<name>   Install branch (default: main)
  --dir=<path>      Install path  (default: \$DETERMINAGENTS_HOME or ~/.determinagents)
  --bin=<path>      Shim path     (default: \$DETERMINAGENTS_BIN  or ~/.local/bin)
HELP
      exit 0
      ;;
  esac
done

# Require git
command -v git >/dev/null 2>&1 || {
  echo "error: git is required but not installed" >&2
  exit 1
}

# Local detection prompt
if [ "$IN_REPO" = true ] && [ -z "${DETERMINAGENTS_HOME:-}" ] && [ "$INSTALL_DIR" = "$HOME/.determinagents" ] && [ -t 0 ]; then
  echo "Local repository detected: $(pwd)"
  echo "  1: Use in-place (stays here, no network)"
  echo "  2: Copy to $INSTALL_DIR (installs to default, no network)"
  echo "  3: Download fresh from GitHub (uses network)"
  printf "Choice? [1] "
  read -r CHOICE
  case "$CHOICE" in
    2)
      LOCAL_COPY=true
      ;;
    3)
      FORCE_UPDATE=true
      ;;
    *)
      INSTALL_DIR=$(pwd)
      ;;
  esac
fi

echo "Determinagents → $INSTALL_DIR (branch: $BRANCH)"

# Install or update
if [ -d "$INSTALL_DIR/.git" ]; then
  if [ "${FORCE_UPDATE:-false}" = false ] && [ "$INSTALL_DIR" = "$(pwd)" ] && [ "$IN_REPO" = true ]; then
    echo "  using local repository; skipping network update"
  else
    echo "  existing checkout found; updating..."
    git -C "$INSTALL_DIR" fetch --quiet origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout --quiet "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only --quiet origin "$BRANCH"
  fi
elif [ "${LOCAL_COPY:-false}" = true ]; then
  echo "  installing local copy to $INSTALL_DIR..."
  if [ -e "$INSTALL_DIR" ]; then
    echo "error: $INSTALL_DIR exists. Please remove it first." >&2
    exit 1
  fi
  git clone --quiet --branch "$BRANCH" "$(pwd)" "$INSTALL_DIR"
else
  if [ -e "$INSTALL_DIR" ]; then
    echo "error: $INSTALL_DIR exists but is not a git checkout" >&2
    echo "  remove it or set \$DETERMINAGENTS_HOME to a different path" >&2
    exit 1
  fi
  git clone --quiet --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

# Install the determinagents shim
mkdir -p "$BIN_DIR"
if [ "$INSTALL_DIR" = "$HOME/.determinagents" ]; then
  cp "$INSTALL_DIR/bin/determinagents" "$BIN_DIR/determinagents"
else
  # Bake the path into the shim for non-standard installs
  sed "s|DETERMINAGENTS_HOME=\"\$HOME/.determinagents\"|DETERMINAGENTS_HOME=\"$INSTALL_DIR\"|" \
    "$INSTALL_DIR/bin/determinagents" > "$BIN_DIR/determinagents"
fi
chmod +x "$BIN_DIR/determinagents"

# Status
SHA=$(git -C "$INSTALL_DIR" rev-parse --short HEAD)
COMMIT_DATE=$(git -C "$INSTALL_DIR" log -1 --format=%cd --date=short)
echo "  installed: $SHA ($COMMIT_DATE)"
echo "  shim:      $BIN_DIR/determinagents"
echo ""

# PATH check
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo "warning: $BIN_DIR is not in your PATH"
    echo "  add this to your shell rc:"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
    ;;
esac

# Suggest the env var if not set, so subsequent invocations resolve correctly
if [ -z "${DETERMINAGENTS_HOME:-}" ] && [ "$INSTALL_DIR" != "$HOME/.determinagents" ]; then
  echo "tip: you installed to a non-default path. Set this in your shell rc:"
  echo "    export DETERMINAGENTS_HOME=\"$INSTALL_DIR\""
  echo ""
fi

cat <<DONE
Done.

Next:
  determinagents version           # show installed version
  determinagents update            # check for updates
  determinagents materialize       # install slash commands for your host tool

To invoke an audit, paste a prompt from $INSTALL_DIR/INVOCATIONS.md
into your coding agent.
DONE
