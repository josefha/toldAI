#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Read local credentials without echoing them or putting them in shell history.
local_env=$(supabase status -o env 2>/dev/null)
export TEST_SUPABASE_URL=$(printf '%s\n' "$local_env" | sed -n 's/^API_URL="\(.*\)"$/\1/p')
export TEST_SUPABASE_SERVICE_KEY=$(printf '%s\n' "$local_env" | sed -n 's/^SERVICE_ROLE_KEY="\(.*\)"$/\1/p')
export TEST_SUPABASE_ANON_KEY=$(printf '%s\n' "$local_env" | sed -n 's/^ANON_KEY="\(.*\)"$/\1/p')
[ -n "$TEST_SUPABASE_SERVICE_KEY" ] || { echo 'Start local Supabase first.'; exit 1; }
npm --prefix backend test
