#!/bin/bash

echo "============================================="
echo "Lab 04: Cleanup"
echo "============================================="
echo ""

echo "Stopping and removing containers..."
docker-compose down -v

echo ""
echo "Removing keytabs..."
rm -rf keytabs

echo ""
echo "============================================="
echo "✓ Cleanup Complete!"
echo "============================================="
echo ""
echo "Both realms have been removed."
echo "Your .env file has been preserved."
echo ""
