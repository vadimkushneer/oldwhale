#!/usr/bin/env bash
# Initialize submodules if you cloned without --recurse-submodules.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
git submodule update --init --recursive
