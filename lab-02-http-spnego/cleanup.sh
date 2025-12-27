#!/bin/bash

echo "========================================="
echo "Lab 02: Cleanup"
echo "========================================="
echo ""

echo "Stopping and removing containers..."
docker-compose down -v

echo ""
echo "Removing keytabs..."
rm -f keytabs/http.keytab

echo ""
echo "========================================="
echo "✓ Cleanup Complete!"
echo "========================================="
echo ""
echo "The lab environment has been removed."
echo "Your .env file has been preserved."
echo ""
