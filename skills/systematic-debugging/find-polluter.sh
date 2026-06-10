#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Usage: ./find-polluter.sh <file_or_dir_to_check> <test_name_pattern>
# Example: ./find-polluter.sh '.git' '*.test.ts'

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <file_to_check> <test_name_pattern>"
  echo "Example: $0 '.git' '*.test.ts'"
  exit 1
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="$2"

echo "🔍 Searching for test that creates: $POLLUTION_CHECK"
echo "Test pattern: $TEST_PATTERN"
echo ""

# Get list of test files (-name, not -path: find emits paths prefixed
# with ./, so '-path src/**/*.test.ts' matches nothing and the script
# reported "all tests clean" after running zero tests)
TEST_FILES=$(find . -type f -name "$TEST_PATTERN" -not -path '*/node_modules/*' | sort)
TOTAL=$(printf '%s' "$TEST_FILES" | grep -c . || true)

if [ "$TOTAL" -eq 0 ]; then
  echo "❌ Pattern '$TEST_PATTERN' matched no test files - refusing to report a clean run"
  exit 2
fi

if [ -e "$POLLUTION_CHECK" ]; then
  echo "❌ '$POLLUTION_CHECK' already exists before any test ran - clean it up first"
  echo "   (a pre-polluted state would skip every test and prove nothing)"
  exit 2
fi

echo "Found $TOTAL test files"
echo ""

COUNT=0
for TEST_FILE in $TEST_FILES; do
  COUNT=$((COUNT + 1))

  # Skip if pollution already exists
  if [ -e "$POLLUTION_CHECK" ]; then
    echo "⚠️  Pollution already exists before test $COUNT/$TOTAL"
    echo "   Skipping: $TEST_FILE"
    continue
  fi

  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run the test
  npm test "$TEST_FILE" > /dev/null 2>&1 || true

  # Check if pollution appeared
  if [ -e "$POLLUTION_CHECK" ]; then
    echo ""
    echo "🎯 FOUND POLLUTER!"
    echo "   Test: $TEST_FILE"
    echo "   Created: $POLLUTION_CHECK"
    echo ""
    echo "Pollution details:"
    ls -la "$POLLUTION_CHECK"
    echo ""
    echo "To investigate:"
    echo "  npm test $TEST_FILE    # Run just this test"
    echo "  cat $TEST_FILE         # Review test code"
    exit 1
  fi
done

echo ""
echo "✅ No polluter found - all tests clean!"
exit 0
