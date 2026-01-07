#!/bin/bash

echo "========================================="
echo "Lab 03: SSH GSSAPI Authentication Tests"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Test 1: Verify SSH server is reachable
echo "Test 1: Checking SSH server connectivity..."
nc -zv ssh.example.com 22 &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "SSH server is reachable on port 22"
else
    print_result 1 "Cannot reach SSH server"
fi

# Test 2: Obtain Kerberos ticket
echo "Test 2: Obtaining Kerberos ticket..."
echo "userpass123" | kinit testuser@EXAMPLE.COM 2>&1
if [ $? -eq 0 ]; then
    print_result 0 "Kerberos ticket obtained successfully"
else
    print_result 1 "Failed to obtain Kerberos ticket"
fi

# Test 3: Verify ticket
echo "Test 3: Verifying Kerberos ticket..."
klist &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Valid Kerberos ticket exists"
    echo "Current tickets:"
    klist
    echo ""
else
    print_result 1 "No valid Kerberos ticket found"
fi

# Test 4: SSH connection with GSSAPI (passwordless)
echo "Test 4: Testing SSH connection with GSSAPI..."
ssh -o GSSAPIAuthentication=yes \
    -o PreferredAuthentications=gssapi-with-mic \
    -o PasswordAuthentication=no \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "echo 'SSH GSSAPI authentication successful'" &> /tmp/ssh_test.log

if grep -q "SSH GSSAPI authentication successful" /tmp/ssh_test.log; then
    print_result 0 "SSH authentication via GSSAPI succeeded"
else
    print_result 1 "SSH authentication via GSSAPI failed"
    echo "Debug output:"
    cat /tmp/ssh_test.log
    echo ""
fi

# Test 5: Verify host service ticket was obtained
echo "Test 5: Checking for host service ticket..."
klist | grep "host/ssh.example.com" &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Host service ticket acquired"
else
    print_result 1 "No host service ticket found"
fi

# Test 6: Test credential delegation (forwarding)
echo "Test 6: Testing credential delegation..."
ssh -o GSSAPIAuthentication=yes \
    -o GSSAPIDelegateCredentials=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "klist" &> /tmp/ssh_forward.log

if grep -q "krbtgt/EXAMPLE.COM@EXAMPLE.COM" /tmp/ssh_forward.log; then
    print_result 0 "Credential delegation (forwarding) works"
    echo "Forwarded tickets on remote host:"
    cat /tmp/ssh_forward.log
    echo ""
else
    print_result 1 "Credential delegation failed"
fi

# Test 7: Test SSH without ticket (should fail)
echo "Test 7: Testing SSH without Kerberos ticket..."
kdestroy
ssh -o GSSAPIAuthentication=yes \
    -o PreferredAuthentications=gssapi-with-mic \
    -o PasswordAuthentication=no \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    testuser@ssh.example.com "echo 'authenticated'" &> /tmp/ssh_noticket.log

if ! grep -q "authenticated" /tmp/ssh_noticket.log; then
    print_result 0 "SSH correctly requires Kerberos ticket"
else
    print_result 1 "SSH should have failed without ticket"
fi

# Test 8: Test command execution over SSH
echo "Test 8: Testing remote command execution..."
echo "userpass123" | kinit testuser@EXAMPLE.COM 2>&1
result=$(ssh -o GSSAPIAuthentication=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "hostname && whoami" 2>/dev/null)

if [[ "$result" == *"ssh.example.com"* ]] && [[ "$result" == *"testuser"* ]]; then
    print_result 0 "Remote command execution works"
    echo "Command output:"
    echo "$result"
    echo ""
else
    print_result 1 "Remote command execution failed"
fi

# Test 9: Verify SSH server has valid keytab
echo "Test 9: Checking SSH server keytab..."
keytab_check=$(ssh -o GSSAPIAuthentication=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "sudo klist -k /etc/krb5.keytab 2>/dev/null | grep -c 'host/ssh.example.com'" 2>/dev/null || echo "0")

if [ "$keytab_check" -gt 0 ]; then
    print_result 0 "SSH server has valid keytab"
else
    print_result 1 "SSH server keytab check failed (may require sudo access)"
fi

# Test 10: Test multiple sessions
echo "Test 10: Testing multiple concurrent SSH sessions..."
ssh -o GSSAPIAuthentication=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "echo 'Session 1'" &> /tmp/session1.log &

ssh -o GSSAPIAuthentication=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    testuser@ssh.example.com "echo 'Session 2'" &> /tmp/session2.log &

wait

if grep -q "Session 1" /tmp/session1.log && grep -q "Session 2" /tmp/session2.log; then
    print_result 0 "Multiple concurrent sessions work"
else
    print_result 1 "Multiple session test failed"
fi

# Cleanup
kdestroy

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo ""
    echo "🎉 SSH with Kerberos GSSAPI is working correctly!"
    echo ""
    echo "Key achievements:"
    echo "  ✓ Passwordless SSH authentication"
    echo "  ✓ Ticket-based access control"
    echo "  ✓ Credential delegation/forwarding"
    echo "  ✓ Remote command execution"
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the configuration.${NC}"
    exit 1
fi
