#!/bin/bash

echo "========================================="
echo "Lab 02: HTTP SPNEGO Authentication Tests"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}: $2"
        ((FAILED++))
    fi
    echo ""
}

# Test 1: Public page access (should work without authentication)
echo "Test 1: Accessing public page..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://web.example.com/)
if [ "$response" = "200" ]; then
    print_result 0 "Public page accessible without authentication"
else
    print_result 1 "Public page returned HTTP $response (expected 200)"
fi

# Test 2: Secure page without ticket (should fail with 401)
echo "Test 2: Accessing secure page without Kerberos ticket..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://web.example.com/secure/)
if [ "$response" = "401" ]; then
    print_result 0 "Secure page correctly requires authentication"
else
    print_result 1 "Secure page returned HTTP $response (expected 401)"
fi

# Test 3: Get Kerberos ticket
echo "Test 3: Obtaining Kerberos ticket..."
echo "userpass123" | kinit testuser@EXAMPLE.COM 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "Kerberos ticket obtained successfully"
else
    print_result 1 "Failed to obtain Kerberos ticket"
fi

# Test 4: Verify ticket was issued
echo "Test 4: Verifying ticket..."
klist &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Kerberos ticket is valid"
    echo "Current tickets:"
    klist
    echo ""
else
    print_result 1 "No valid Kerberos ticket found"
fi

# Test 5: Access secure page with ticket (should succeed)
echo "Test 5: Accessing secure page with Kerberos ticket..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://web.example.com/secure/)
if [ "$response" = "200" ]; then
    print_result 0 "Secure page accessible with valid ticket"
else
    print_result 1 "Secure page returned HTTP $response (expected 200)"
fi

# Test 6: Access admin page with testuser (should succeed)
echo "Test 6: Accessing admin page with authorized user..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://web.example.com/admin/)
if [ "$response" = "200" ]; then
    print_result 0 "Admin page accessible for authorized principal"
else
    print_result 1 "Admin page returned HTTP $response (expected 200)"
fi

# Test 7: View service ticket
echo "Test 7: Checking service ticket acquisition..."
klist | grep "HTTP/web.example.com" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Service ticket for HTTP/web.example.com acquired"
else
    print_result 1 "No service ticket found for HTTP/web.example.com"
fi

# Test 8: Destroy ticket and verify access is denied
echo "Test 8: Testing ticket destruction..."
kdestroy
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://web.example.com/secure/)
if [ "$response" = "401" ]; then
    print_result 0 "Access denied after ticket destruction"
else
    print_result 1 "Access check returned HTTP $response (expected 401)"
fi

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the configuration.${NC}"
    exit 1
fi
