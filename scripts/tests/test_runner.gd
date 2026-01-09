class_name TestRunner
extends Node

## Base class for test scenes
## Provides assertion helpers and automatic test execution

var _test_name: String = "UnnamedTest"
var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test: String = ""

signal all_tests_completed(passed: int, failed: int)


func _ready() -> void:
	# Give scene a frame to initialize
	await get_tree().process_frame
	run_tests()


## Override this in subclasses to run your tests
func run_tests() -> void:
	_log_header()
	# Subclasses implement their tests here
	_log_summary()


func _log_header() -> void:
	print("")
	print("=" .repeat(60))
	print("TEST SUITE: ", _test_name)
	print("=" .repeat(60))


func _log_summary() -> void:
	print("-" .repeat(60))
	if _tests_failed == 0:
		print("RESULT: ALL TESTS PASSED (%d/%d)" % [_tests_passed, _tests_run])
	else:
		print("RESULT: FAILED (%d passed, %d failed)" % [_tests_passed, _tests_failed])
	print("=" .repeat(60))
	print("")
	all_tests_completed.emit(_tests_passed, _tests_failed)
	# Auto-quit when running headless (e.g., from command line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _tests_failed == 0 else 1)


## Start a named test
func test(name: String) -> void:
	_current_test = name
	_tests_run += 1


## Assert that a condition is true
func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		_pass(message)
		return true
	else:
		_fail(message)
		return false


## Assert that a condition is false
func assert_false(condition: bool, message: String = "") -> bool:
	return assert_true(not condition, message)


## Assert that two values are equal
func assert_eq(actual, expected, message: String = "") -> bool:
	if actual == expected:
		_pass(message if message else "Expected %s, got %s" % [expected, actual])
		return true
	else:
		_fail("Expected %s, got %s. %s" % [expected, actual, message])
		return false


## Assert that two float values are approximately equal (within tolerance)
func assert_approx_eq(actual: float, expected: float, message: String = "", tolerance: float = 0.1) -> bool:
	if abs(actual - expected) <= tolerance:
		_pass(message if message else "Expected ~%s, got %s" % [expected, actual])
		return true
	else:
		_fail("Expected ~%s (±%s), got %s. %s" % [expected, tolerance, actual, message])
		return false


## Assert that two values are not equal
func assert_neq(actual, not_expected, message: String = "") -> bool:
	if actual != not_expected:
		_pass(message)
		return true
	else:
		_fail("Expected NOT %s, but got it. %s" % [not_expected, message])
		return false


## Assert that a value is null
func assert_null(value, message: String = "") -> bool:
	if value == null:
		_pass(message if message else "Value is null")
		return true
	else:
		_fail("Expected null, got %s. %s" % [value, message])
		return false


## Assert that a value is not null
func assert_not_null(value, message: String = "") -> bool:
	if value != null:
		_pass(message if message else "Value is not null")
		return true
	else:
		_fail("Expected non-null value. %s" % message)
		return false


## Assert array length
func assert_array_size(arr: Array, expected_size: int, message: String = "") -> bool:
	if arr.size() == expected_size:
		_pass(message if message else "Array size is %d" % expected_size)
		return true
	else:
		_fail("Expected array size %d, got %d. %s" % [expected_size, arr.size(), message])
		return false


## Assert array contains item
func assert_array_contains(arr: Array, item, message: String = "") -> bool:
	if arr.has(item):
		_pass(message if message else "Array contains item")
		return true
	else:
		_fail("Array does not contain expected item. %s" % message)
		return false


## Assert array does not contain item
func assert_array_not_contains(arr: Array, item, message: String = "") -> bool:
	if not arr.has(item):
		_pass(message if message else "Array does not contain item")
		return true
	else:
		_fail("Array unexpectedly contains item. %s" % message)
		return false


func _pass(message: String) -> void:
	_tests_passed += 1
	print("  [PASS] %s: %s" % [_current_test, message if message else "OK"])


func _fail(message: String) -> void:
	_tests_failed += 1
	print("  [FAIL] %s: %s" % [_current_test, message])
