extends Control

# 拖放处理脚本
# 用于接收从文件管理器拖拽ZIP文件到窗口

func _ready() -> void:
	print("=== DropOverlay _ready ===")
	# 确保这个控件可以接收拖放
	mouse_filter = Control.MOUSE_FILTER_STOP  # 改为STOP以捕获事件

func _input(event: InputEvent) -> void:
	# 打印所有输入事件用于调试
	print("=== DropOverlay _input event type:", event.get_class(), " action:", event.as_text() if event is InputEventAction else "")
	# 不阻止事件传播，让Control的拖放处理函数处理

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	print("=== DropOverlay _can_drop_data ===", data, " type:", typeof(data))

	# 接受文件拖放
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("files"):
			var files = data["files"]
			print("=== DropOverlay files:", files)
			if files.size() > 0:
				var file_path = str(files[0])
				print("=== DropOverlay file_path:", file_path)
				return file_path.to_lower().ends_with(".zip")
		# Godot内部的拖放也接受
		print("=== DropOverlay accepting internal drag ===")
		return true
	elif typeof(data) == TYPE_ARRAY:
		print("=== DropOverlay array data:", data)
		if data.size() > 0:
			var file_path = str(data[0])
			return file_path.to_lower().ends_with(".zip")

	return false

func _get_drag_data(at_position: Vector2) -> Variant:
	print("=== DropOverlay _get_drag_data ===", at_position)
	return null

func _drop_data(at_position: Vector2, data: Variant) -> void:
	print("=== DropOverlay _drop_data ===", data, " type:", typeof(data))

	# 查找父控制器
	var mod_manager = null
	var parent = get_parent()
	while parent:
		print("=== checking parent:", parent)
		if parent.has_method("install_mod_from_path"):
			mod_manager = parent
			break
		parent = parent.get_parent()

	if mod_manager:
		print("=== found mod_manager:", mod_manager)
		var files = []

		if typeof(data) == TYPE_DICTIONARY and data.has("files"):
			files = data["files"]
		elif typeof(data) == TYPE_ARRAY:
			files = data

		print("=== files:", files)
		for file_path in files:
			var path_str = str(file_path)
			print("=== processing:", path_str)
			if path_str.to_lower().ends_with(".zip"):
				mod_manager.install_mod_from_path(path_str)
	else:
		print("=== DropOverlay: parent modmanager not found ===")
