extends Control
class_name LaunchButton

## 启动游戏按钮控件
## 点击展开子选项：原版启动、模组启动、联机启动

signal launch_mode_pressed(mode: String)  # mode: "vanilla", "modded", "multiplayer"

var is_expanded: bool = false
var main_button: Button
var triangle_icon: Polygon2D
var sub_buttons: Array = []  # [vanilla, modded, multiplayer]
var sub_labels: Array = []  # 提示标签
var expanded_radius: float = 70.0  # 子选项展开半径

# 子选项配置
var modes: Array = [
	{"mode": "vanilla", "label": "原版启动", "color": Color(0.2, 0.7, 0.4, 1)},  # 绿色-树叶
	{"mode": "modded", "label": "模组启动", "color": Color(0.9, 0.5, 0.2, 1)},   # 橙色-扳手
	{"mode": "multiplayer", "label": "联机启动", "color": Color(0.25, 0.5, 0.9, 1)}  # 蓝色-交换机
]

func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -100  # 向界面中心移动，距离边界更远
	offset_top = -100
	offset_right = -20
	offset_bottom = -20

	_create_main_button()
	_create_sub_buttons()
	_hide_sub_buttons()


func _process(delta: float) -> void:
	queue_redraw()


func _create_main_button() -> void:
	# 主按钮 - 圆形背景
	main_button = Button.new()
	main_button.name = "MainButton"
	main_button.custom_minimum_size = Vector2(48, 48)
	main_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_button.focus_mode = Control.FOCUS_NONE
	main_button.pressed.connect(_on_main_button_pressed)

	# 圆形样式
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.5, 0.7, 1)
	normal_style.corner_radius_top_left = 24
	normal_style.corner_radius_top_right = 24
	normal_style.corner_radius_bottom_right = 24
	normal_style.corner_radius_bottom_left = 24
	main_button.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.6, 0.8, 1)
	hover_style.corner_radius_top_left = 24
	hover_style.corner_radius_top_right = 24
	hover_style.corner_radius_bottom_right = 24
	hover_style.corner_radius_bottom_left = 24
	main_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.4, 0.6, 1)
	pressed_style.corner_radius_top_left = 24
	pressed_style.corner_radius_top_right = 24
	pressed_style.corner_radius_bottom_right = 24
	pressed_style.corner_radius_bottom_left = 24
	main_button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.4, 0.6, 1)
	disabled_style.corner_radius_top_left = 24
	disabled_style.corner_radius_top_right = 24
	disabled_style.corner_radius_bottom_right = 24
	disabled_style.corner_radius_bottom_left = 24
	main_button.add_theme_stylebox_override("disabled", disabled_style)

	add_child(main_button)

	# 三角形图标 (播放符号 ▶)
	triangle_icon = Polygon2D.new()
	triangle_icon.name = "TriangleIcon"
	var triangle_points = PackedVector2Array([
		Vector2(-4, -8),
		Vector2(-4, 8),
		Vector2(8, 0)
	])
	triangle_icon.polygon = triangle_points
	triangle_icon.color = Color.WHITE
	triangle_icon.position = Vector2(24, 24)  # 居中
	main_button.add_child(triangle_icon)


func _create_sub_buttons() -> void:
	for i in range(modes.size()):
		var mode_data = modes[i]

		# 创建子按钮容器
		var btn = Button.new()
		btn.name = "SubButton_" + mode_data["mode"]
		btn.custom_minimum_size = Vector2(40, 40)
		btn.visible = false
		btn.pivot_offset = Vector2(20, 20)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		# 圆形样式
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = mode_data["color"]
		normal_style.corner_radius_top_left = 20
		normal_style.corner_radius_top_right = 20
		normal_style.corner_radius_bottom_right = 20
		normal_style.corner_radius_bottom_left = 20
		btn.add_theme_stylebox_override("normal", normal_style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = mode_data["color"].lightened(0.15)
		hover_style.corner_radius_top_left = 20
		hover_style.corner_radius_top_right = 20
		hover_style.corner_radius_bottom_right = 20
		hover_style.corner_radius_bottom_left = 20
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = mode_data["color"].darkened(0.15)
		pressed_style.corner_radius_top_left = 20
		pressed_style.corner_radius_top_right = 20
		pressed_style.corner_radius_bottom_right = 20
		pressed_style.corner_radius_bottom_left = 20
		btn.add_theme_stylebox_override("pressed", pressed_style)

		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = mode_data["color"].darkened(0.2)
		disabled_style.corner_radius_top_left = 20
		disabled_style.corner_radius_top_right = 20
		disabled_style.corner_radius_bottom_right = 20
		disabled_style.corner_radius_bottom_left = 20
		btn.add_theme_stylebox_override("disabled", disabled_style)

		# 创建图标（根据模式）
		var icon = _create_icon_for_mode(mode_data["mode"])
		icon.position = Vector2(20, 20)
		btn.add_child(icon)

		# 点击事件
		var mode = mode_data["mode"]
		btn.pressed.connect(func(): _on_sub_button_pressed(mode))

		# 鼠标悬停事件
		btn.mouse_entered.connect(_on_sub_button_mouse_entered.bind(i))
		btn.mouse_exited.connect(_on_sub_button_mouse_exited.bind(i))

		# 创建提示标签（作为 LaunchButton 的子节点）
		var label = Label.new()
		label.name = "TooltipLabel_" + mode_data["mode"]
		label.text = mode_data["label"]
		label.modulate.a = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.custom_minimum_size = Vector2(80, 24)
		label.visible = false
		label.z_index = 10
		add_child(label)
		sub_labels.append(label)

		# 插入到主按钮下面（保持层级）
		add_child(btn)
		sub_buttons.append(btn)


func _hide_sub_buttons() -> void:
	for i in range(sub_buttons.size()):
		var btn = sub_buttons[i]
		btn.visible = false
		btn.modulate.a = 0
		# 重置标签状态
		if i < sub_labels.size():
			var label = sub_labels[i]
			label.visible = false
			label.modulate.a = 0
			label.position = Vector2.ZERO
			label.rotation = 0


func _on_main_button_pressed() -> void:
	if is_expanded:
		_collapse()
	else:
		_expand()


func _expand() -> void:
	is_expanded = true

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(triangle_icon, "rotation", deg_to_rad(90), 0.2)

	var end_angles = [150.0, 210.0, 270.0]
	var center_pos = Vector2(24, 24)
	var orbit_radius = 70.0

	for i in range(sub_buttons.size()):
		var btn = sub_buttons[i]
		var target_angle = end_angles[i]
		btn.visible = true
		btn.modulate.a = 0
		btn.pivot_offset = Vector2(20, 20)
		btn.position = center_pos - Vector2(20, 20)
		btn.rotation = 0

		var t = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_SINE)

		var start_angle_inner = 180.0
		var center = center_pos
		var radius = orbit_radius
		var button = btn
		var target = target_angle

		t.tween_method(_update_orbiting_button.bind(button, center, radius, start_angle_inner), start_angle_inner, target, 0.4)
		t.tween_property(btn, "modulate:a", 1.0, 0.3)

func _collapse() -> void:
	is_expanded = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(triangle_icon, "rotation", 0.0, 0.2)

	var end_angles = [150.0, 210.0, 270.0]
	var center_pos = Vector2(24, 24)
	var orbit_radius = 70.0

	for i in range(sub_buttons.size()):
		var btn = sub_buttons[i]
		var start_angle_inner = end_angles[i]
		var target_collapse = 180.0

		var t = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_IN)
		t.set_trans(Tween.TRANS_SINE)

		var center = center_pos
		var radius = orbit_radius
		var button = btn

		t.tween_method(_update_orbiting_button.bind(button, center, radius, start_angle_inner), start_angle_inner, target_collapse, 0.3)
		t.tween_property(btn, "modulate:a", 0.0, 0.25)
		t.tween_callback(func():
			btn.visible = false
		).set_delay(0.25)


func _on_sub_button_pressed(mode: String) -> void:
	print("[LaunchButton] Selected mode: ", mode)
	_collapse()
	launch_mode_pressed.emit(mode)


func _on_sub_button_mouse_entered(index: int) -> void:
	if index < 0 or index >= sub_labels.size() or index >= sub_buttons.size():
		return
	var label = sub_labels[index]
	var btn = sub_buttons[index]

	# 获取按钮相对于 LaunchButton 的位置
	var btn_pos = btn.position
	var btn_size = btn.size

	# 最终位置：按钮左侧外80px处（完全显示）
	var final_x = btn_pos.x - 80
	var label_y = btn_pos.y + btn_size.y / 2 - 12

	# 初始位置：紧贴按钮左边缘（从边缘处淡入）
	label.position = Vector2(btn_pos.x, label_y)
	label.visible = true
	label.rotation = 0  # 保持水平

	# 从按钮边缘向外淡入动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	# 同时移动和淡入
	tween.tween_property(label, "position:x", final_x, 0.2)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.2)


func _on_sub_button_mouse_exited(index: int) -> void:
	if index < 0 or index >= sub_labels.size() or index >= sub_buttons.size():
		return
	var label = sub_labels[index]
	var btn = sub_buttons[index]

	# 获取按钮位置
	var btn_pos = btn.position

	# 退出位置：紧贴按钮左边缘（到边缘处消失）
	var exit_x = btn_pos.x

	# 向按钮边缘移动并淡出
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	# 同时移动和淡出
	tween.tween_property(label, "position:x", exit_x, 0.15)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		label.visible = false
	)


func _create_icon_for_mode(mode: String) -> Control:
	var container = Control.new()
	container.name = "Icon"

	match mode:
		"vanilla":
			# 树叶形状 - 菱形主体 + 中线
			var leaf = Polygon2D.new()
			leaf.polygon = PackedVector2Array([
				Vector2(0, -8),
				Vector2(5, -2),
				Vector2(0, 8),
				Vector2(-5, -2)
			])
			leaf.color = Color.WHITE
			container.add_child(leaf)

			# 叶脉
			var vein = Polygon2D.new()
			vein.polygon = PackedVector2Array([
				Vector2(-0.5, -6),
				Vector2(0.5, -6),
				Vector2(0.5, 6),
				Vector2(-0.5, 6)
			])
			vein.color = Color(0.7, 0.7, 0.7, 1)
			container.add_child(vein)

		"modded":
			# 扳手形状
			var handle = Polygon2D.new()
			handle.polygon = PackedVector2Array([
				Vector2(-2, -8),
				Vector2(2, -8),
				Vector2(2, 4),
				Vector2(-2, 4)
			])
			handle.color = Color.WHITE
			container.add_child(handle)

			var head = Polygon2D.new()
			head.polygon = PackedVector2Array([
				Vector2(-5, 4),
				Vector2(5, 4),
				Vector2(5, 8),
				Vector2(2, 8),
				Vector2(2, 6),
				Vector2(-2, 6),
				Vector2(-2, 8),
				Vector2(-5, 8)
			])
			head.color = Color.WHITE
			container.add_child(head)

		"multiplayer":
			# 交换机形状
			var box = Polygon2D.new()
			box.polygon = PackedVector2Array([
				Vector2(-4, -3),
				Vector2(4, -3),
				Vector2(4, 3),
				Vector2(-4, 3)
			])
			box.color = Color.WHITE
			container.add_child(box)

			var line1 = Polygon2D.new()
			line1.polygon = PackedVector2Array([
				Vector2(-6, -8), Vector2(-2, -8),
				Vector2(-2, -3), Vector2(-6, -3)
			])
			line1.color = Color.WHITE
			container.add_child(line1)

			var line2 = Polygon2D.new()
			line2.polygon = PackedVector2Array([
				Vector2(-1, -3), Vector2(1, -3),
				Vector2(1, -8), Vector2(-1, -8)
			])
			line2.color = Color.WHITE
			container.add_child(line2)

			var line3 = Polygon2D.new()
			line3.polygon = PackedVector2Array([
				Vector2(2, -3), Vector2(6, -3),
				Vector2(6, -8), Vector2(2, -8)
			])
			line3.color = Color.WHITE
			container.add_child(line3)

		_:
			var tri = Polygon2D.new()
			tri.polygon = PackedVector2Array([
				Vector2(-3, -6),
				Vector2(-3, 6),
				Vector2(6, 0)
			])
			tri.color = Color.WHITE
			container.add_child(tri)

	return container


func _update_orbiting_button(angle_deg: float, button: Button, center: Vector2, radius: float, start_angle: float) -> void:
	var rad = deg_to_rad(angle_deg)
	button.position = center + Vector2(radius * cos(rad), radius * sin(rad)) - Vector2(20, 20)
	button.rotation = deg_to_rad(angle_deg - start_angle)


# 点击空白区域收起
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_expanded:
			# 检查是否点击在按钮外部
			var mouse_pos = get_local_mouse_position()
			var btn_rect = Rect2(Vector2.ZERO, size)
			if not btn_rect.has_point(mouse_pos):
				# 检查是否点击在子按钮上
				var clicked_sub = false
				for btn in sub_buttons:
					if btn.visible and btn.get_global_rect().has_point(event.position):
						clicked_sub = true
						break
				if not clicked_sub:
					_collapse()
