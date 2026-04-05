extends PanelContainer

# 模组详情面板脚本

# UI节点引用
@onready var title_label: Label
@onready var name_value: Label

# 当前显示的模组数据
var current_mod_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始显示空状态
	clear_details()


# 设置模组详情
func setup(mod_data: Dictionary) -> void:
	current_mod_data = mod_data
	
	if mod_data.is_empty():
		clear_details()
		return

	# 更新UI
	title_label.text = "模组详情"
	name_value.text = mod_data.get("name", "Unknown")


# 清空详情显示
func clear_details() -> void:
	current_mod_data.clear()
	title_label.text = "模组详情"
	name_value.text = "-"


# 获取当前模组数据
func get_mod_data() -> Dictionary:
	return current_mod_data

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
