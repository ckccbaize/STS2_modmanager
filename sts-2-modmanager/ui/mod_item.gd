extends PanelContainer

# 模组列表项脚本

# UI节点引用
@onready var hbox: HBoxContainer = $HBox
@onready var bg_color: ColorRect = $BgColor
@onready var chk_enabled: CheckBox = $HBox/CheckBox
@onready var lbl_name: Label = $HBox/NameLabel
@onready var lbl_version: Label = $HBox/VersionLabel
@onready var lbl_author: Label = $HBox/AuthorLabel
@onready var lbl_type: Label = $HBox/TypeLabel

# 数据
var mod_data: Dictionary = {}  # 模组数据
var is_selected: bool = false  # 选中状态
var multi_select_mode: bool = false  # 多选模式
var missing_dependencies: Array = []  # 缺少的依赖列表
var on_toggled_callback: Callable  # 复选框状态变化回调
var on_selected_callback: Callable  # 选中回调（点击项）
var on_batch_toggle_callback: Callable  # 批量切换回调（多选模式下复选框变化）

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 连接复选框信号
	if chk_enabled:
		chk_enabled.toggled.connect(_on_checkbox_toggled)

	# 连接到根节点(PanelContainer)的gui_input
	gui_input.connect(_on_gui_input)

	# 设置默认背景颜色
	if bg_color:
		bg_color.color = Color(0.13, 0.13, 0.13, 1)
		bg_color.visible = true


# 设置模组数据
func setup(data: Dictionary, enabled: bool = false) -> void:
	mod_data = data

	# 更新UI显示
	if lbl_name:
		lbl_name.text = data.get("name", "Unknown")
		# 截断时显示开头部分 + "..."
		lbl_name.text_overrun_behavior = 4  # OVERRUN_TRIM_HEAD_ELLIPSIS
	if lbl_version:
		lbl_version.text = data.get("version", "v1.0.0")
		# 版本号截断显示末尾
		lbl_version.text_overrun_behavior = 6  # OVERRUN_TRIM_TAIL_ELLIPSIS
	if lbl_author:
		lbl_author.text = data.get("author", "Unknown")
		# 作者名截断显示开头
		lbl_author.text_overrun_behavior = 4  # OVERRUN_TRIM_HEAD_ELLIPSIS

	# 设置类型标签（始终显示玩法/外观）
	var affects_gameplay = data.get("affects_gameplay", false)
	if lbl_type:
		if affects_gameplay:
			lbl_type.text = "玩法"
			lbl_type.add_theme_color_override("font_color", Color("#ff7085"))  # 红色
		else:
			lbl_type.text = "外观"
			lbl_type.add_theme_color_override("font_color", Color("#42ffc2"))  # 绿色

	# 设置下载来源背景色（仅作为背景标识）
	# 获取下载来源
	var download_source = data.get("download_source", "")
	var has_nexus_source = not download_source.is_empty() and (download_source == "nexus" or download_source == "nexusmods")

	# 获取缺少依赖
	var missing_deps = data.get("missing_dependencies", [])

	# 设置背景颜色（优先级：红色 > 黄色）
	if not missing_deps.is_empty():
		# 缺少依赖 - 标红（优先级最高）
		if bg_color:
			bg_color.color = Color(1.0, 0.4, 0.4, 0.2)  # 淡红色
	elif has_nexus_source:
		# N网来源 - 标黄（仅当没有缺少依赖时）
		if bg_color:
			bg_color.color = Color(1.0, 0.95, 0.6, 0.15)  # 淡黄色背景

	# 保存缺失依赖信息
	missing_dependencies = missing_deps

	# 设置复选框状态 (不触发信号)
	if chk_enabled:
		chk_enabled.toggled.disconnect(_on_checkbox_toggled)
		chk_enabled.button_pressed = enabled
		chk_enabled.toggled.connect(_on_checkbox_toggled)


# 复选框状态变化处理
func _on_checkbox_toggled(toggled_on: bool) -> void:
	print("=== checkbox toggled ===", mod_data.get("name", ""), toggled_on)

	if multi_select_mode and on_batch_toggle_callback:
		# 多选模式下，复选框变化触发批量操作
		on_batch_toggle_callback.call(mod_data, toggled_on)
	elif on_toggled_callback:
		on_toggled_callback.call(mod_data, toggled_on)


# GUI输入处理（点击选中）
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if on_selected_callback:
				if multi_select_mode:
					# 多选模式下，切换当前项的选中状态
					is_selected = not is_selected
					set_selected(is_selected)
					# 传递选中状态给回调
					on_selected_callback.call(mod_data, is_selected)
				else:
					# 单选模式
					on_selected_callback.call(mod_data)


# 获取模组ID
func get_mod_id() -> String:
	return mod_data.get("id", "")


# 更新启用状态
func update_enabled_status(enabled: bool) -> void:
	if chk_enabled:
		chk_enabled.toggled.disconnect(_on_checkbox_toggled)
		chk_enabled.button_pressed = enabled
		chk_enabled.toggled.connect(_on_checkbox_toggled)


# 设置选中状态
func set_selected(selected: bool) -> void:
	is_selected = selected
	# 视觉反馈 - 改变背景颜色
	var missing_deps = mod_data.get("missing_dependencies", [])
	var has_nexus_source = false
	var download_source = mod_data.get("download_source", "")
	if not download_source.is_empty() and (download_source == "nexus" or download_source == "nexusmods"):
		has_nexus_source = true

	if bg_color:
		if selected:
			if not missing_deps.is_empty():
				bg_color.color = Color(1.0, 0.4, 0.4, 0.3)  # 选中+缺少依赖红色
			elif has_nexus_source:
				bg_color.color = Color(1.0, 0.95, 0.6, 0.3)  # 选中+N网黄色
			else:
				bg_color.color = Color(0.25, 0.25, 0.25, 1.0)  # 选中普通灰色
		else:
			if not missing_deps.is_empty():
				bg_color.color = Color(1.0, 0.4, 0.4, 0.2)  # 未选中+缺少依赖红色
			elif has_nexus_source:
				bg_color.color = Color(1.0, 0.95, 0.6, 0.15)  # 未选中+N网黄色
			else:
				bg_color.color = Color(0.13, 0.13, 0.13, 1)  # 默认


# 获取选中状态
func get_selected() -> bool:
	return is_selected


# 设置多选模式
func set_multi_select_mode(enabled: bool) -> void:
	multi_select_mode = enabled


# 设置批量切换回调
func set_batch_toggle_callback(callback: Callable) -> void:
	on_batch_toggle_callback = callback
