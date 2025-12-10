#!/usr/bin/env bash
# Example PRE_DEPLOY job for Next.js application
# This script demonstrates database migration patterns
set -euo pipefail

echo "[PRE-DEPLOY] =========================================="
echo "[PRE-DEPLOY] Next.js Pre-Deploy Job Example"
echo "[PRE-DEPLOY] =========================================="
echo ""

# Example: Check environment variables
echo "[PRE-DEPLOY] Step 1: Validating environment..."
if [ -z "${DATABASE_URL:-}" ]; then
    echo "[PRE-DEPLOY]   ⚠ DATABASE_URL not set (development mode)"
else
    echo "[PRE-DEPLOY]   ✓ DATABASE_URL configured"
fi
echo ""

# Example: Database migration simulation
echo "[PRE-DEPLOY] Step 2: Running database migrations..."
echo "[PRE-DEPLOY]   → Checking migration status..."
sleep 1
echo "[PRE-DEPLOY]   → Applying pending migrations..."
sleep 1
echo "[PRE-DEPLOY]   ✓ All migrations applied"
echo ""

# Example: Build static assets if needed
echo "[PRE-DEPLOY] Step 3: Preparing static assets..."
sleep 0.5
echo "[PRE-DEPLOY]   ✓ Assets ready"
echo ""

echo "[PRE-DEPLOY] =========================================="
echo "[PRE-DEPLOY] ✓ Pre-Deploy Completed Successfully"
echo "[PRE-DEPLOY] =========================================="
echo ""

exit 0
