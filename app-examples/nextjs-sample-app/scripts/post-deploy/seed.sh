#!/usr/bin/env bash
# Example POST_DEPLOY job for Next.js application
# This script demonstrates post-deployment tasks
set -euo pipefail

echo "[POST-DEPLOY] =========================================="
echo "[POST-DEPLOY] Next.js Post-Deploy Job Example"
echo "[POST-DEPLOY] =========================================="
echo ""

# Example: Cache warming
echo "[POST-DEPLOY] Step 1: Warming application cache..."
sleep 1
echo "[POST-DEPLOY]   ✓ Cache warmed"
echo ""

# Example: Database seeding (optional data)
echo "[POST-DEPLOY] Step 2: Seeding sample data..."
echo "[POST-DEPLOY]   → Checking if data exists..."
sleep 0.5
echo "[POST-DEPLOY]   → Creating sample records..."
sleep 1
echo "[POST-DEPLOY]   ✓ Sample data created"
echo ""

# Example: Trigger analytics or notifications
echo "[POST-DEPLOY] Step 3: Sending deployment notifications..."
sleep 0.5
echo "[POST-DEPLOY]   ✓ Notifications sent"
echo ""

echo "[POST-DEPLOY] =========================================="
echo "[POST-DEPLOY] ✓ Post-Deploy Completed Successfully"
echo "[POST-DEPLOY] =========================================="
echo ""

exit 0
