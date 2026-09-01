#!/usr/bin/env bash
# Read-only PX4 expected-param compare via mavlink-router UDP. No MAVROS.
set -euo pipefail
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
SCRIPT="${HERE}/check-px4-params.py"
if [[ ! -f "${SCRIPT}" ]]; then
  SCRIPT=/usr/lib/xgc2/fs150/check-px4-params.py
fi
ENDPOINT="${FS150_MAVLINK_ENDPOINT:-127.0.0.1:14561}"
if [[ -n "${FS150_PX4_EXPECTED:-}" ]]; then
  exec python3 "${SCRIPT}" --endpoint "${ENDPOINT}" --expected "${FS150_PX4_EXPECTED}" "$@"
fi
exec python3 "${SCRIPT}" --endpoint "${ENDPOINT}" "$@"
