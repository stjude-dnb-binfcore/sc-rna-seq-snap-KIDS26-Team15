#!/usr/bin/env bash
set -euo pipefail

# Launch downstream snap workflow (upstream onwards) via Sprocket.
#
# Usage:
#   bash scripts/launch-snap-sprocket.sh [--snap-root PATH] [--update-yaml] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPDATE_YAML=0
DRY_RUN=0
INPUTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --snap-root) SNAP_ROOT="$2"; shift 2 ;;
    --inputs) INPUTS="$2"; shift 2 ;;
    --update-yaml) UPDATE_YAML=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: bash scripts/launch-snap-sprocket.sh [--snap-root PATH] [--update-yaml] [--dry-run]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

WDL_DIR="${SNAP_ROOT}/wdl"
WORKFLOW="${WDL_DIR}/snap.wdl"
CONFIG="${SNAP_ROOT}/sprocket.toml"
GENERATED="${SNAP_ROOT}/inputs/generated_downstream.json"

mkdir -p "${SNAP_ROOT}/inputs"

if ! command -v sprocket >/dev/null 2>&1; then
  echo "sprocket not found. On St. Jude HPC: module load sprocket"
  exit 1
fi

UPDATE_FLAG=()
[[ "${UPDATE_YAML}" -eq 1 ]] && UPDATE_FLAG=(--update-yaml)

echo "==> Estimating downstream resources"
Rscript "${SCRIPT_DIR}/estimate-snap-downstream-resources.R" \
  --snap-root "${SNAP_ROOT}" \
  --output "${GENERATED}" \
  "${UPDATE_FLAG[@]}"

[[ -z "${INPUTS}" ]] && INPUTS="${GENERATED}"

echo "==> Checking WDL"
sprocket check "${WORKFLOW}"

if command -v jq >/dev/null 2>&1 && jq -e '.sprocket_inputs' "${INPUTS}" >/dev/null 2>&1; then
  FLAT="${SNAP_ROOT}/inputs/.generated_flat.json"
  jq '.sprocket_inputs' "${INPUTS}" > "${FLAT}"
  INPUTS="${FLAT}"
fi

echo "==> Validating inputs"
sprocket validate "${WORKFLOW}" -i "${INPUTS}"

[[ "${DRY_RUN}" -eq 1 ]] && { echo "Dry run complete."; exit 0; }

echo "==> Submitting downstream workflow"
sprocket run "${WORKFLOW}" -i "${INPUTS}" --config "${CONFIG}"
