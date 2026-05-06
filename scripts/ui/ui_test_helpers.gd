extends Node
class_name UI_TestHelpers

func node_exists(path: String) -> bool:
    return has_node(path)

func assert_node_exists(path: String) -> void:
    if not node_exists(path):
        push_error("Missing UI node at %s" % path)
