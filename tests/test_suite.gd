class_name TestSuite
extends RefCounted
## Minimal assertion base for headless tests run by res://tests/run_tests.gd.
## Each `test_*` method runs once; failures are collected, not thrown.

const DEFAULT_EPSILON := 0.0001

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()
var checks: int = 0
var _current_test: String = ""


func begin(test_name: String) -> void:
	_current_test = test_name


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_current_test, message])


func check_near(actual: float, expected: float, message: String, epsilon: float = DEFAULT_EPSILON) -> void:
	check(absf(actual - expected) <= epsilon,
		"%s (expected %.5f, got %.5f)" % [message, expected, actual])


func check_vec_near(actual: Vector3, expected: Vector3, message: String, epsilon: float = DEFAULT_EPSILON) -> void:
	check(actual.distance_to(expected) <= epsilon,
		"%s (expected %s, got %s)" % [message, expected, actual])


## Adds a node under the test root and returns it; freed by cleanup().
func spawn(node: Node) -> Node:
	node.set_meta(&"test_node", true)
	tree.root.add_child(node)
	return node


func cleanup() -> void:
	for child: Node in tree.root.get_children():
		if child.has_meta(&"test_node"):
			child.free()
