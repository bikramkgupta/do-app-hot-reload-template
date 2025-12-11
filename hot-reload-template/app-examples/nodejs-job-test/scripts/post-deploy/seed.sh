#!/usr/bin/env bash
# Example POST_DEPLOY job: Database seeding simulation
# This script simulates seeding database with sample data after app starts
set -euo pipefail

echo "[POST-DEPLOY] =========================================="
echo "[POST-DEPLOY] Starting Database Seed"
echo "[POST-DEPLOY] =========================================="
echo ""

# Simulate checking if seeding is needed
echo "[POST-DEPLOY] Step 1: Checking existing data..."
sleep 1
echo "[POST-DEPLOY]   → Database is empty, seeding required"
echo ""

# Simulate seeding users
echo "[POST-DEPLOY] Step 2: Seeding user data..."
echo "[POST-DEPLOY]   → Creating admin user..."
sleep 0.5
echo "[POST-DEPLOY]   ✓ Admin user created"
echo "[POST-DEPLOY]   → Creating 10 test users..."
sleep 1
echo "[POST-DEPLOY]   ✓ 10 test users created"
echo ""

# Simulate seeding products
echo "[POST-DEPLOY] Step 3: Seeding product catalog..."
echo "[POST-DEPLOY]   → Creating product categories..."
sleep 0.5
echo "[POST-DEPLOY]   ✓ 5 categories created"
echo "[POST-DEPLOY]   → Creating products..."
sleep 1
echo "[POST-DEPLOY]   ✓ 25 products created"
echo ""

# Simulate cache warming
echo "[POST-DEPLOY] Step 4: Warming application cache..."
sleep 1
echo "[POST-DEPLOY]   ✓ Cache warmed successfully"
echo ""

echo "[POST-DEPLOY] =========================================="
echo "[POST-DEPLOY] ✓ Seeding Completed Successfully!"
echo "[POST-DEPLOY] =========================================="
echo ""

exit 0
