#!/bin/bash

# Simple test for Set-NFT-Transferable Inbox delivery
# Using minimal contract to isolate the issue

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NFT_BLUEPRINT="$SCRIPT_DIR/test-set-transferable-simple.lua"

# Configuration
INBOX_CHECK_INTERVAL=5
INBOX_MAX_WAIT_TIME=60

# Helper functions
get_current_inbox_length() {
    local process_id="$1"

    # Use the same logic as main test script - parse the inbox length from ao-cli output
    local raw_output
    local json_output

    raw_output=$(ao-cli eval "$process_id" --data 'return #Inbox' --wait 2>/dev/null)
    json_output=$(echo "$raw_output" | jq -s '.[-1]' 2>/dev/null)

    if echo "$json_output" | jq -e '.success == true' >/dev/null 2>&1; then
        local current_length=$(echo "$json_output" | jq -r '.data.result.Output.data // empty' 2>/dev/null)
        if [[ -z "$current_length" ]]; then
            current_length=$(echo "$json_output" | jq -r '.result.Output.data // empty' 2>/dev/null)
        fi
        if [[ -z "$current_length" ]]; then
            current_length=$(echo "$json_output" | jq -r '.Output.data // empty' 2>/dev/null)
        fi
        if [[ -z "$current_length" ]]; then
            current_length=$(echo "$raw_output" | grep -o '"data": *"[^"]*"' | sed 's/.*"data": *"\([^"]*\)".*/\1/' | tail -1)
        fi
        if [[ "$current_length" =~ ^[0-9]+$ ]]; then
            echo "$current_length"
            return
        fi
    fi

    # Direct extraction from the output line that contains the number
    local data_line=$(echo "$raw_output" | grep "Data:" | tail -1)
    if [[ -n "$data_line" ]]; then
        local number=$(echo "$data_line" | sed 's/.*Data: *"\([^"]*\)".*/\1/' | grep -o '[0-9]\+')
        if [[ "$number" =~ ^[0-9]+$ ]]; then
            echo "$number"
            return
        fi
    fi

    echo "0"
}

wait_for_expected_inbox_length() {
    local process_id="$1"
    local expected_length="$2"
    local max_wait="${3:-$INBOX_MAX_WAIT_TIME}"
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        local current_length=$(get_current_inbox_length "$process_id")

        if [[ "$current_length" -ge "$expected_length" ]]; then
            echo "✅ Inbox reached expected length after ${waited}s (current: $current_length >= expected: $expected_length)"
            return 0
        fi

        echo "   📊 Inbox check (${waited}s): current = $current_length, expected = $expected_length"
        sleep $INBOX_CHECK_INTERVAL
        waited=$((waited + INBOX_CHECK_INTERVAL))
    done

    echo "❌ Inbox did not reach expected length within ${max_wait}s timeout (final: $current_length, expected: $expected_length)"
    return 1
}

# Main test
echo "=== Simple Set-NFT-Transferable Inbox Delivery Test ==="
echo ""

# Spawn a fresh test process
echo "🔧 Spawning fresh test process..."
RAW_OUTPUT=$(ao-cli spawn default --name "test-set-transferable-$(date +%s)" 2>&1)
echo "Spawn output: $RAW_OUTPUT"

# Extract process ID from output (it might be in a different format)
TEST_PROCESS_ID=$(echo "$RAW_OUTPUT" | grep -o 'Process ID: [a-zA-Z0-9_-]*' | cut -d' ' -f3)
if [[ -z "$TEST_PROCESS_ID" ]]; then
    # Try alternative format
    TEST_PROCESS_ID=$(echo "$RAW_OUTPUT" | grep -o '[a-zA-Z0-9_-]\{43\}' | head -1)
fi

if [[ -n "$TEST_PROCESS_ID" ]]; then
    echo "✅ Fresh test process created: $TEST_PROCESS_ID"
else
    echo "❌ Failed to spawn test process or extract process ID"
    echo "Raw output: $RAW_OUTPUT"
    exit 1
fi

# Load blueprint
echo ""
echo "📦 Loading simple test blueprint..."
RAW_OUTPUT=$(ao-cli load "$TEST_PROCESS_ID" "$NFT_BLUEPRINT" 2>&1)
echo "Load output: $RAW_OUTPUT"

# Check if load was successful (look for success message or lack of error)
if echo "$RAW_OUTPUT" | grep -q "loaded successfully\|success"; then
    echo "✅ Simple test blueprint loaded successfully"
else
    echo "❌ Failed to load test blueprint"
    echo "Raw output: $RAW_OUTPUT"
    exit 1
fi

# Wait for stabilization
echo ""
echo "⏳ Waiting for process stabilization..."
sleep 10

# Get initial inbox length
INITIAL_INBOX_LENGTH=$(get_current_inbox_length "$TEST_PROCESS_ID")
echo "📊 Initial Inbox length: $INITIAL_INBOX_LENGTH"

# Test Set-NFT-Transferable
echo ""
echo "🧪 Testing Set-NFT-Transferable Inbox delivery..."
echo "Setting TokenId 'test-123' transferable status to 'true'"

EXPECTED_INBOX_LENGTH=$((INITIAL_INBOX_LENGTH + 1))
echo "📊 Expected inbox length after response: $EXPECTED_INBOX_LENGTH"

# Send test message with trace
echo ""
echo "📤 Sending Set-NFT-Transferable request with --trace..."
TRACE_OUTPUT=$(ao-cli eval "$TEST_PROCESS_ID" --data 'Send({Target="'$TEST_PROCESS_ID'", Action="Set-NFT-Transferable", TokenId="test-123", Transferable="true"})' --wait --trace)
echo "🔍 Trace output:"
echo "$TRACE_OUTPUT" | sed 's/^/   /'

# Always check inbox delivery regardless of trace success
echo "✅ Set-NFT-Transferable request sent (checking trace output for handler execution)"

# Check inbox delivery - THIS IS THE CRITICAL TEST
echo ""
echo "🔍 CRITICAL TEST: Checking if response message entered Inbox..."
echo "   📊 Before request: $INITIAL_INBOX_LENGTH messages"
echo "   📊 Expected after: $EXPECTED_INBOX_LENGTH messages"

# Use the same logic as main test script
if wait_for_expected_inbox_length "$TEST_PROCESS_ID" "$EXPECTED_INBOX_LENGTH" 60; then
    echo "✅ SUCCESS: Set-NFT-Transferable response received in Inbox!"

    # Get final inbox length
    FINAL_INBOX_LENGTH=$(get_current_inbox_length "$TEST_PROCESS_ID")
    echo "   📊 Inbox increased from $INITIAL_INBOX_LENGTH to $FINAL_INBOX_LENGTH"

    # Show inbox details
    echo ""
    echo "📨 FINAL INBOX DETAILS:"
    ao-cli eval "$TEST_PROCESS_ID" --data 'for i=1,#Inbox do print(string.format("Inbox[%d]: Action=%s, From=%s", i, Inbox[i].Action or "nil", Inbox[i].From or "nil")) end' --wait 2>/dev/null

    echo ""
    echo "📄 LATEST MESSAGE CONTENT:"
    ao-cli eval "$TEST_PROCESS_ID" --data 'local msg = Inbox[#Inbox]; print("Action: " .. (msg.Action or "nil")); print("Data: " .. (msg.Data or "nil")); print("From: " .. (msg.From or "nil"))' --wait 2>/dev/null
else
    echo "❌ FAILURE: Set-NFT-Transferable response NOT received in Inbox within timeout"
    echo "   📝 This confirms the fundamental Inbox delivery issue!"

    # Show current inbox anyway for debugging
    echo ""
    echo "📨 CURRENT INBOX STATUS (for debugging):"
    ao-cli eval "$TEST_PROCESS_ID" --data 'for i=1,#Inbox do print(string.format("Inbox[%d]: Action=%s, From=%s", i, Inbox[i].Action or "nil", Inbox[i].From or "nil")) end' --wait 2>/dev/null
fi

echo ""
echo "=== Test completed ==="
