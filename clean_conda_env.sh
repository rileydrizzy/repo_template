#!/usr/bin/env bash
# =============================================================================
# clean_lightning_env.sh
# Removes all user-installed packages from a Lightning AI Studio environment.
# Works around Lightning's single-env restriction (no conda deactivate/activate).
#
# Usage:
#   chmod +x clean_lightning_env.sh
#   ./clean_lightning_env.sh
# =============================================================================

set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ── Confirmation ──────────────────────────────────────────────────────────────
warn "This will REMOVE ALL user-installed packages from the current environment."
warn "Core packages (python, pip, conda, setuptools, etc.) will be preserved."
echo ""
read -rp "Continue? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
echo ""

# ── STEP 1: Backup (optional) ─────────────────────────────────────────────────
BACKUP_FILE="requirements_backup_$(date +%Y%m%d_%H%M%S).txt"
info "Saving current pip packages to $BACKUP_FILE ..."
pip freeze > "$BACKUP_FILE" 2>/dev/null && success "Backup saved: $BACKUP_FILE" || warn "Could not save backup."

# ── STEP 2: Remove pip packages ───────────────────────────────────────────────
info "Collecting pip-installed packages..."
PIP_PKGS=$(pip list --format=freeze 2>/dev/null \
  | grep -v "^-e" \
  | cut -d= -f1 \
  || true)

if [[ -n "$PIP_PKGS" ]]; then
  info "Uninstalling pip packages..."
  echo "$PIP_PKGS" | xargs pip uninstall -y
  success "pip packages removed."
else
  info "No pip packages found."
fi

# ── STEP 3: Remove conda packages ─────────────────────────────────────────────
# These are kept to avoid breaking the environment
KEEP_PATTERN='^(conda|python|pip|setuptools|wheel|certifi|_libgcc_mutex|_openmp_mutex|libgcc-ng|libstdcxx-ng|ca-certificates|openssl|sqlite|xz|zlib|ncurses|readline|tk|bzip2|ld_impl_linux|libffi|libuuid|libgdbm)$'

info "Collecting conda-managed packages..."
CONDA_PKGS=$(conda list \
  | tail -n +3 \
  | awk '{print $1}' \
  | grep -vE "$KEEP_PATTERN" \
  || true)

if [[ -n "$CONDA_PKGS" ]]; then
  info "Removing conda packages..."
  echo "$CONDA_PKGS" | xargs conda remove --yes 2>/dev/null \
    && success "conda packages removed." \
    || warn "Some conda packages could not be removed (may be pinned dependencies). Continuing..."
else
  info "No additional conda packages to remove."
fi

# ── STEP 4: Clean conda cache ─────────────────────────────────────────────────
info "Cleaning conda cache..."
conda clean --all --yes
success "Cache cleaned."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Environment cleaned."
echo ""
info "Remaining packages:"
conda list
echo ""
info "To restore your previous packages, run:"
echo "    pip install -r $BACKUP_FILE"