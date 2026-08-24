@tool
extends EditorPlugin

func _enter_tree() -> void:
	print("[Maestro] Plugin enabled.")

func _exit_tree() -> void:
	print("[Maestro] Plugin disabled.")
