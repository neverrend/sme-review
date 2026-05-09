#!/usr/bin/env sh
set -eu

CATALOG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="sme-review"
SKILL_SRC="$CATALOG_DIR/$SKILL_NAME"
SKILL_DEST="$HOME/.claude/skills/$SKILL_NAME"
MODE="${1:-copy}"

FORCE=0
for arg in "$@"; do
  if [ "$arg" = "--force" ]; then FORCE=1; fi
done

if [ ! -d "$SKILL_SRC" ]; then echo "Error: $SKILL_SRC not found." >&2; exit 1; fi

if [ -d "$HOME/.claude" ] && [ ! -w "$HOME/.claude" ]; then
  echo "$HOME/.claude is not writable. Check ownership: ls -la $HOME/.claude" >&2
  exit 1
fi

mkdir -p "$HOME/.claude/skills"

if [ "$MODE" = "symlink" ]; then
  case "$SKILL_SRC" in
    "$HOME/Documents/"*|"$HOME/Desktop/"*|"$HOME/iCloud Drive/"*)
      echo "Warning: source is in an iCloud-managed path; symlinks may break on file eviction. Consider 'copy' mode." >&2 ;;
  esac
fi

if [ -L "$SKILL_DEST" ] && [ "$(readlink "$SKILL_DEST")" = "$SKILL_SRC" ] && [ "$MODE" = "symlink" ]; then
  echo "Already installed (symlink → $SKILL_SRC). No changes."
  exit 0
fi

if [ -e "$SKILL_DEST" ] || [ -L "$SKILL_DEST" ]; then
  if [ "$FORCE" -eq 1 ]; then
    rm -rf "$SKILL_DEST"
  else
    echo "Existing install at $SKILL_DEST. Re-run with --force to overwrite." >&2
    exit 1
  fi
fi

case "$MODE" in
  symlink) ln -s "$SKILL_SRC" "$SKILL_DEST"; echo "Symlinked $SKILL_DEST → $SKILL_SRC" ;;
  copy)    cp -R "$SKILL_SRC" "$SKILL_DEST"; echo "Copied $SKILL_SRC → $SKILL_DEST" ;;
  *)       echo "Unknown mode: $MODE. Use 'copy' or 'symlink'." >&2; exit 1 ;;
esac

echo "Installed. Verify: ls -la $SKILL_DEST"
