#!/bin/bash
# Run all test suites for the Multi-Step Interaction System
# Usage: ./run_tests.sh
# Exit code: 0 if all pass, 1 if any fail

GODOT="/Users/nikkikoole/Downloads/Godot 3.app/Contents/MacOS/Godot"
TEST_DIR="res://scenes/tests"

# List of test scenes (excluding test_base.tscn which is just the base class)
TESTS=(
    "test_items"
    "test_job"
    "test_jobboard"
    "test_station"
    "test_agent_hauling"
    "test_agent_working"
    "test_need_jobs"
    "test_recipe_cook"
    "test_recipe_eat_snack"
    "test_recipe_toilet"
    "test_recipe_tv"
    "test_interruption"
    "test_debug_commands"
    "test_job_integration"
    "test_debug_cooking_scenario"
    "test_debug_interruption_scenario"
    "test_ground_items"
)

total_passed=0
failed_tests=()

echo "========================================"
echo "Running All Tests"
echo "========================================"
echo ""

for test in "${TESTS[@]}"; do
    # Run test and capture output
    output=$("$GODOT" --headless "${TEST_DIR}/${test}.tscn" 2>&1)
    exit_code=$?

    # Extract results from output
    if echo "$output" | grep -q "ALL TESTS PASSED"; then
        # Extract count like "PASSED (73/13)" -> 73
        passed=$(echo "$output" | grep "ALL TESTS PASSED" | sed 's/.*(\([0-9]*\).*/\1/')
        echo "[PASS] $test ($passed assertions)"
        total_passed=$((total_passed + passed))
    else
        echo "[FAIL] $test"
        echo "$output" | grep "\[FAIL\]"
        failed_tests+=("$test")
    fi
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Total assertions passed: $total_passed"
echo "Failed test suites: ${#failed_tests[@]} of ${#TESTS[@]}"

if [ ${#failed_tests[@]} -eq 0 ]; then
    echo ""
    echo "ALL TESTS PASSED"
    exit 0
else
    echo ""
    echo "FAILED TESTS:"
    for t in "${failed_tests[@]}"; do
        echo "  - $t"
    done
    exit 1
fi
