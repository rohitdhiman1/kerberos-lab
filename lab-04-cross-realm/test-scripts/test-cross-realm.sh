#!/bin/bash

echo "============================================="
echo "Lab 04: Cross-Realm Trust Tests"
echo "============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

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

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_section "REALM-A Tests (alice@REALM-A.LOCAL)"

# Test 1: Authenticate as alice
echo "Test 1: Authenticating as alice@REALM-A.LOCAL..."
echo "alicepass123" | kinit alice@REALM-A.LOCAL 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "Authentication successful for alice"
else
    print_result 1 "Failed to authenticate alice"
fi

# Test 2: Verify TGT
echo "Test 2: Verifying TGT for alice..."
klist | grep "krbtgt/REALM-A.LOCAL@REALM-A.LOCAL" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "TGT acquired for alice"
    echo "Current tickets:"
    klist
    echo ""
else
    print_result 1 "No TGT found for alice"
fi

# Test 3: Access local service (same realm)
echo "Test 3: Accessing Service-A (same realm)..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://service.realm-a.local/secure/)
if [ "$response" = "200" ]; then
    print_result 0 "Local realm access successful (alice → Service-A)"
else
    print_result 1 "Local realm access failed (HTTP $response)"
fi

# Test 4: Verify service ticket for Service-A
echo "Test 4: Checking service ticket for Service-A..."
klist | grep "HTTP/service.realm-a.local@REALM-A.LOCAL" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Service ticket acquired for Service-A"
else
    print_result 1 "No service ticket found for Service-A"
fi

print_section "Cross-Realm Tests (alice → REALM-B)"

# Test 5: Access cross-realm service
echo "Test 5: Accessing Service-B (cross-realm)..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://service.realm-b.local/secure/)
if [ "$response" = "200" ]; then
    print_result 0 "Cross-realm access successful (alice → Service-B)"
else
    print_result 1 "Cross-realm access failed (HTTP $response)"
fi

# Test 6: Verify referral ticket
echo "Test 6: Checking referral ticket (krbtgt/REALM-B.LOCAL@REALM-A.LOCAL)..."
klist | grep "krbtgt/REALM-B.LOCAL@REALM-A.LOCAL" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Referral ticket acquired"
else
    print_result 1 "No referral ticket found"
fi

# Test 7: Verify cross-realm service ticket
echo "Test 7: Checking cross-realm service ticket..."
klist | grep "HTTP/service.realm-b.local@REALM-B.LOCAL" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Cross-realm service ticket acquired"
else
    print_result 1 "No cross-realm service ticket found"
fi

# Test 8: Display all tickets
echo "Test 8: Displaying complete ticket cache..."
echo ""
echo -e "${YELLOW}=== Current Ticket Cache ===${NC}"
klist
echo ""
print_result 0 "Ticket cache displayed"

# Test 9: Clean up and test bob
print_section "REALM-B Tests (bob@REALM-B.LOCAL)"

kdestroy
echo "Test 9: Authenticating as bob@REALM-B.LOCAL..."
echo "bobpass123" | kinit bob@REALM-B.LOCAL 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "Authentication successful for bob"
else
    print_result 1 "Failed to authenticate bob"
fi

# Test 10: Bob accesses Service-B (local)
echo "Test 10: Bob accessing Service-B (same realm)..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://service.realm-b.local/secure/)
if [ "$response" = "200" ]; then
    print_result 0 "Local realm access successful (bob → Service-B)"
else
    print_result 1 "Local realm access failed (HTTP $response)"
fi

# Test 11: Bob accesses Service-A (cross-realm)
echo "Test 11: Bob accessing Service-A (cross-realm)..."
response=$(curl -s -o /dev/null -w "%{http_code}" --negotiate -u : http://service.realm-a.local/secure/)
if [ "$response" = "200" ]; then
    print_result 0 "Reverse cross-realm access successful (bob → Service-A)"
else
    print_result 1 "Reverse cross-realm access failed (HTTP $response)"
fi

# Test 12: Verify bob's cross-realm tickets
echo "Test 12: Checking bob's cross-realm tickets..."
klist | grep "krbtgt/REALM-A.LOCAL@REALM-B.LOCAL" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Bob's referral ticket acquired"
else
    print_result 1 "No referral ticket found for bob"
fi

echo ""
echo -e "${YELLOW}=== Bob's Ticket Cache ===${NC}"
klist
echo ""

print_section "Trust Verification Tests"

# Test 13: Verify trust principals exist
echo "Test 13: Verifying trust principals on KDCs..."
trust_a=$(docker exec kdc-realm-a kadmin.local -q "listprincs" | grep "krbtgt/REALM-B.LOCAL@REALM-A.LOCAL" | wc -l)
trust_b=$(docker exec kdc-realm-b kadmin.local -q "listprincs" | grep "krbtgt/REALM-A.LOCAL@REALM-B.LOCAL" | wc -l)

if [ $trust_a -gt 0 ] && [ $trust_b -gt 0 ]; then
    print_result 0 "Cross-realm trust principals verified on both KDCs"
else
    print_result 1 "Trust principals missing (A: $trust_a, B: $trust_b)"
fi

# Test 14: Verify capaths configuration
echo "Test 14: Checking capaths configuration..."
if grep -q "capaths" /etc/krb5.conf && grep -q "REALM-A.LOCAL" /etc/krb5.conf && grep -q "REALM-B.LOCAL" /etc/krb5.conf; then
    print_result 0 "capaths section properly configured"
else
    print_result 1 "capaths configuration incomplete"
fi

# Cleanup
kdestroy

# Summary
print_section "Test Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}All tests passed! Cross-realm trust is working correctly! ✓${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Some tests failed. Please review the configuration.${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
