#!/usr/bin/env bash
#
# Infrahub's compose stack (DB, message queue, task manager, server,
# task-worker, etc.) is generated and maintained upstream, and changes
# fairly often between releases. Rather than hand-maintain a copy that
# can drift out of sync, fetch the current one directly.
#
# Run this from inside stacks/infrahub/:
#
#   ./fetch-base-compose.sh
#
set -euo pipefail

OUT="docker-compose.yml"

if [ -f "$OUT" ]; then
  echo "Backing up existing $OUT -> ${OUT}.bak"
  mv "$OUT" "${OUT}.bak"
fi

curl -fsSL https://infrahub.opsmill.io -o "$OUT"

echo "Downloaded $OUT"
echo
echo "Next steps:"
echo "  1. Open $OUT and confirm the server/worker service names"
echo "     (used to be 'infrahub-git', now 'task-worker' -- check yours)."
echo "  2. Update docker-compose.override.yml if the names differ."
echo "  3. Set secrets in .env (see .env.example)."
echo "  4. docker compose -f $OUT -f docker-compose.override.yml up -d"
