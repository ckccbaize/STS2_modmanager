extends PanelContainer

# 存档列表项脚本

# UI节点引用
@onready var bg_color: ColorRect = $BgColor
@onready var hbox: HBoxContainer = $HBox
@onready var lbl_name: Label = $HBox/NameLabel
@onready var lbl_date: Label = $HBox/DateLabel
@onready var lbl_type: Label = $HBox/TypeLabel
@onready var lbl_size: Label = $HBox/SizeLabel

var save_data: Dictionary = {}
var on_select_callback: Callable
var is_selected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 连接点击事件
	gui_input.connect(_on_gui_input)

	# 设置默认背景颜色
	if bg_color:
		bg_color.color = Color(0.13, 0.13, 0.13, 1)
		bg_color.visible = true


# 设置存档数据
func setup(data: Dictionary) -> void:
	save_data = data
	print("[save_item.setup] Called with data: ", data)

	# 构建显示名称：账号 - 存档# [模组版]
	var display_name = data.get("full_name", data.get("name", "Unknown"))
	print("[save_item.setup] display_name: ", display_name)
	if lbl_name:
		lbl_name.text = display_name
		print("[save_item.setup] NameLabel set to: ", lbl_name.text)

	if lbl_date:
		lbl_date.text = data.get("date", "Unknown Date")

	if lbl_type:
		# 显示类型：steam/modded + 当前游戏状态
		var save_type = data.get("type", "steam")
		if data.get("has_current_save", false):
			lbl_type.text = save_type + " (有当前游戏)"
		else:
			lbl_type.text = save_type

	if lbl_size:
		lbl_size.text = data.get("size", "0 KB")

	print("[save_item.setup] Complete")


# GUI输入处理（点击选中）
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if on_select_callback:
				on_select_callback.call(save_data)


# 获取存档数据
func get_save_data() -> Dictionary:
	return save_data


# 设置选中状态
func set_selected(selected: bool) -> void:
	is_selected = selected
	# 可以添加视觉反馈


# 获取选中状态
func get_selected() -> bool:
	return is_selected
