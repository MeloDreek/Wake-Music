#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_sdk="${MEGASDK_ROOT:-$task_root/../../本地公开库/MEGASDK}"
task_bootstrap="$task_sdk/tools/wake-bootstrap-artifacts.sh"
if [ ! -f "$task_bootstrap" ]; then
    echo "Shared MEGASDK not found: $task_sdk. Set MEGASDK_ROOT if it is stored elsewhere." >&2
    exit 1
fi
exec bash "$task_bootstrap" "$@"
