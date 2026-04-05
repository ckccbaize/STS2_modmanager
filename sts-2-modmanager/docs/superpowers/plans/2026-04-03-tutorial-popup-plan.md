# 教程弹窗实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 首次启动时显示分步向导式教程，引导用户完成初始配置（游戏路径）并介绍核心功能（模组管理、存档管理、Nexus下载）

**架构：** 在 modmanager.gd 中新增教程弹窗逻辑，使用 Window/Panel 实现居中向导式 UI，通过 config 中的 game_path 是否为空判断是否首次启动

**技术栈：** Godot 4.5.1, GDScript, Window/Panel 组件

---

## 文件结构

- **修改:** `modmanager.gd` - 添加教程弹窗相关逻辑
- **修改:** `locales/zh_CN.json` - 添加教程相关国际化文本
- **修改:** `locales/en_US.json` - 添加教程相关国际化文本

---

## 任务 1: 添加国际化文本

**Files:**
- Modify: `locales/zh_CN.json`
- Modify: `locales/en_US.json`

- [ ] **Step 1: 在 zh_CN.json 添加教程文本**

在 `"nexus_error_prefix": "错误: "` 后添加:

```json
"tutorial_welcome_title": "欢迎使用",
"tutorial_welcome_content": "杀戮尖塔2模组管理器\n\n帮助您轻松管理游戏模组、存档，并支持从Nexus Mods下载模组。\n\n点击「下一步」开始配置。",
"tutorial_game_path_title": "配置游戏路径",
"tutorial_game_path_content": "首先需要选择游戏的可执行文件。\n\n点击「浏览」选择「SlayTheSpire2.exe」，或点击「自动检测」尝试自动查找游戏安装路径。",
"tutorial_mods_title": "模组管理",
"tutorial_mods_content": "在「模组」标签页，您可以：\n\n• 查看已安装的模组列表\n• 启用/禁用模组\n• 拖放 ZIP 文件安装新模组\n• 批量操作多个模组",
"tutorial_saves_title": "存档管理",
"tutorial_saves_content": "在「存档」标签页，您可以：\n\n• 查看Steam存档和导入的存档\n• 手动或自动备份存档\n• 导入/导出存档\n• 在原版和模组版存档间切换",
"tutorial_nexus_title": "Nexus模组下载",
"tutorial_nexus_content": "通过浏览器扩展下载Nexus模组：\n\n1. 安装浏览器扩展（设置中查看说明）\n2. 在Nexus Mods网站模组页面，点击扩展注入的「下载到管理器」按钮\n3. 模组将自动下载并安装\n\n如无法使用扩展，也可在「N网模组」标签页直接搜索下载。",
"tutorial_skip": "跳过",
"tutorial_prev": "上一步",
"tutorial_next": "下一步",
"tutorial_finish": "完成",
"tutorial_button": "查看教程",
"tutorial_config_game_path": "配置游戏路径",
"tutorial_step": "第 %d 步",
"tutorial_completed": "教程完成！",
"tutorial_set_game_path_hint": "请先在设置中配置游戏路径"
```

- [ ] **Step 2: 在 en_US.json 添加教程文本**

同样添加英文版本（翻译要点）：
- "欢迎使用" → "Welcome"
- "配置游戏路径" → "Configure Game Path"
- "模组管理" → "Mod Management"
- "存档管理" → "Save Management"
- "Nexus模组下载" → "Nexus Mods Download"

- [ ] **Step 3: Commit**

```bash
git add locales/zh_CN.json locales/en_US.json
git commit -m "feat: add tutorial i18n strings"
```

---

## 任务 2: 在 modmanager.gd 添加教程弹窗逻辑

**Files:**
- Modify: `modmanager.gd`

- [ ] **Step 1: 在 modmanager.gd 顶部添加教程状态变量**

在类变量声明区域（约第 50-100 行）添加：

```gdscript
# 教程弹窗状态
var tutorial_panel: Panel = null
var tutorial_current_step: int = 0
var tutorial_steps: Array = ["welcome", "game_path", "mods", "saves", "nexus"]
```

- [ ] **Step 2: 在 _ready() 中添加教程检查逻辑**

在 `load_config()` 后、`load_locale()` 前添加：

```gdscript
# 检查是否需要显示教程（首次启动：game_path 未配置）
if game_path.is_empty():
    print("[_ready] 首次启动，显示教程")
    call_deferred("_show_tutorial_if_needed")
```

- [ ] **Step 3: 添加 _show_tutorial_if_needed() 方法**

在 modmanager.gd 末尾（或其他适当位置）添加：

```gdscript
# 教程弹窗相关方法
func _show_tutorial_if_needed() -> void:
    # 延迟显示，让界面先渲染完成
    await get_tree().create_timer(0.5).timeout
    # 如果 game_path 仍然为空，显示教程
    if game_path.is_empty():
        _create_tutorial_popup()
        _show_tutorial_step(0)

func _create_tutorial_popup() -> void:
    # 如果已存在，先移除
    if tutorial_panel and is_instance_valid(tutorial_panel):
        tutorial_panel.queue_free()
    
    # 创建主面板
    tutorial_panel = Panel.new()
    tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
    tutorial_panel.custom_minimum_size = Vector2(480, 360)
    tutorial_panel.name = "TutorialPanel"
    get_root_control().add_child(tutorial_panel)
    
    # 设置样式（与现代扁平设计保持一致）
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.3, 0.3, 1)
    style.set_corner_radius_all(8)
    tutorial_panel.add_theme_stylebox_override("panel", style)
    
    # 创建内部容器
    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 20)
    tutorial_panel.add_child(vbox)
    
    # === 步骤指示器 ===
    var step_indicator = HBoxContainer.new()
    step_indicator.name = "StepIndicator"
    step_indicator.alignment = BoxContainer.ALIGNMENT_CENTER
    step_indicator.add_theme_constant_override("separation", 12)
    vbox.add_child(step_indicator)
    
    for i in range(5):
        var dot = Label.new()
        dot.text = "●" if i == 0 else "○"
        dot.add_theme_font_size_override("font_size", 16)
        if i == 0:
            dot.add_theme_color_override("font_color", Color(0.2, 0.7, 0.9, 1))
        else:
            dot.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
        step_indicator.add_child(dot)
    
    # === 标题 ===
    var title_label = Label.new()
    title_label.name = "TitleLabel"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 24)
    title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    vbox.add_child(title_label)
    
    # === 内容 ===
    var content_label = RichTextLabel.new()
    content_label.name = "ContentLabel"
    content_label.bbcode_enabled = true
    content_label.fit_content = true
    content_label.custom_minimum_size = Vector2(400, 180)
    content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(content_label)
    
    # === 配置游戏路径步骤的浏览按钮 ===
    var game_path_container = HBoxContainer.new()
    game_path_container.name = "GamePathContainer"
    game_path_container.alignment = BoxContainer.ALIGNMENT_CENTER
    game_path_container.add_theme_constant_override("separation", 10)
    game_path_container.visible = false
    vbox.add_child(game_path_container)
    
    var browse_btn = Button.new()
    browse_btn.text = translate("browse")
    browse_btn.name = "BrowseBtn"
    browse_btn.pressed.connect(_on_tutorial_browse_game_path)
    game_path_container.add_child(browse_btn)
    
    var detect_btn = Button.new()
    detect_btn.text = translate("auto_detect")
    detect_btn.name = "DetectBtn"
    detect_btn.pressed.connect(_on_tutorial_detect_game_path)
    game_path_container.add_child(detect_btn)
    
    # === 按钮行 ===
    var btn_row = HBoxContainer.new()
    btn_row.name = "BtnRow"
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_row.add_theme_constant_override("separation", 20)
    vbox.add_child(btn_row)
    
    var skip_btn = Button.new()
    skip_btn.text = translate("tutorial_skip")
    skip_btn.name = "SkipBtn"
    skip_btn.pressed.connect(_close_tutorial)
    btn_row.add_child(skip_btn)
    
    var prev_btn = Button.new()
    prev_btn.text = translate("tutorial_prev")
    prev_btn.name = "PrevBtn"
    prev_btn.pressed.connect(_tutorial_prev_step)
    btn_row.add_child(prev_btn)
    
    var next_btn = Button.new()
    next_btn.text = translate("tutorial_next")
    next_btn.name = "NextBtn"
    next_btn.pressed.connect(_tutorial_next_step)
    btn_row.add_child(next_btn)

func _show_tutorial_step(step: int) -> void:
    if not tutorial_panel:
        return
    
    tutorial_current_step = step
    var vbox = tutorial_panel.get_node("VBoxContainer")
    
    # 更新步骤指示器
    var step_indicator = vbox.get_node("StepIndicator")
    for i in range(step_indicator.get_child_count()):
        var dot = step_indicator.get_child(i)
        if i == step:
            dot.text = "●"
            dot.add_theme_color_override("font_color", Color(0.2, 0.7, 0.9, 1))
        else:
            dot.text = "○"
            dot.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
    
    # 更新标题和内容
    var title_label = vbox.get_node("TitleLabel")
    var content_label = vbox.get_node("ContentLabel")
    var game_path_container = vbox.get_node("GamePathContainer")
    var btn_row = vbox.get_node("BtnRow")
    var next_btn = btn_row.get_node("NextBtn")
    var prev_btn = btn_row.get_node("PrevBtn")
    
    # 根据步骤显示不同内容
    var step_key = tutorial_steps[step]
    match step_key:
        "welcome":
            title_label.text = translate("tutorial_welcome_title")
            content_label.text = translate("tutorial_welcome_content")
            game_path_container.visible = false
            prev_btn.visible = false
        "game_path":
            title_label.text = translate("tutorial_game_path_title")
            content_label.text = translate("tutorial_game_path_content")
            game_path_container.visible = true
            prev_btn.visible = true
        "mods":
            title_label.text = translate("tutorial_mods_title")
            content_label.text = translate("tutorial_mods_content")
            game_path_container.visible = false
            prev_btn.visible = true
        "saves":
            title_label.text = translate("tutorial_saves_title")
            content_label.text = translate("tutorial_saves_content")
            game_path_container.visible = false
            prev_btn.visible = true
        "nexus":
            title_label.text = translate("tutorial_nexus_title")
            content_label.text = translate("tutorial_nexus_content")
            game_path_container.visible = false
            prev_btn.visible = true
            next_btn.text = translate("tutorial_finish")
    
    # 调整内容区域高度
    if step_key == "game_path":
        content_label.custom_minimum_size = Vector2(400, 120)
    else:
        content_label.custom_minimum_size = Vector2(400, 180)

func _tutorial_next_step() -> void:
    var step_key = tutorial_steps[tutorial_current_step]
    
    # 如果是游戏路径步骤，验证是否已配置
    if step_key == "game_path":
        if game_path.is_empty():
            _show_notification(translate("tutorial_set_game_path_hint"))
            return
    
    if tutorial_current_step < tutorial_steps.size() - 1:
        _show_tutorial_step(tutorial_current_step + 1)
    else:
        # 教程完成
        _close_tutorial()

func _tutorial_prev_step() -> void:
    if tutorial_current_step > 0:
        _show_tutorial_step(tutorial_current_step - 1)

func _close_tutorial() -> void:
    if tutorial_panel and is_instance_valid(tutorial_panel):
        tutorial_panel.queue_free()
        tutorial_panel = null
    
    # 如果 game_path 已配置，保存到 config
    if not game_path.is_empty():
        config.set_value("paths", "game_path", game_path)
        config.save(config_path)
        print("[Tutorial] game_path saved to config")

func _on_tutorial_browse_game_path() -> void:
    _on_select_game_path_pressed()

func _on_tutorial_detect_game_path() -> void:
    _on_detect_game_path_pressed()
    # 刷新教程显示（如果 game_path 已配置）
    if not game_path.is_empty():
        _show_tutorial_step(tutorial_current_step)

func _show_tutorial_from_settings() -> void:
    """从设置页面重新打开教程"""
    if tutorial_panel and is_instance_valid(tutorial_panel):
        return
    _create_tutorial_popup()
    _show_tutorial_step(0)
```

- [ ] **Step 4: 添加设置页教程按钮**

在 `_init_settings_ui_if_needed()` 函数末尾（大约 4932 行附近）添加教程按钮：

```gdscript
# 添加教程按钮（如果不存在）
var tutorial_btn = get_node_or_null("/root/Control/TabContainer/SettingsTab/SettingsScroll/SettingsVBox/TutorialBtn")
if not tutorial_btn:
    tutorial_btn = Button.new()
    tutorial_btn.name = "TutorialBtn"
    tutorial_btn.text = translate("tutorial_button")
    tutorial_btn.pressed.connect(_show_tutorial_from_settings)
    
    # 添加到设置页面底部（在保存按钮之后）
    var settings_vbox = get_node_or_null("/root/Control/TabContainer/SettingsTab/SettingsScroll/SettingsVBox")
    if settings_vbox:
        settings_vbox.add_child(tutorial_btn)
        print("[_init_settings_ui_if_needed] Added tutorial button")
```

- [ ] **Step 5: 测试运行**

启动 Godot 项目，确认：
1. 首次启动时教程弹窗显示
2. 各步骤切换正常
3. 跳过/完成按钮正常工作
4. 设置页面有教程按钮
5. 国际化文本正确显示

- [ ] **Step 6: Commit**

```bash
git add modmanager.gd
git commit -m "feat: add tutorial popup for first-time users"
```

---

## 验证清单

- [ ] 首次启动（game_path 为空）时显示教程弹窗
- [ ] 教程包含 5 个步骤：欢迎、配置游戏路径、模组管理、存档管理、Nexus下载
- [ ] 支持跳过、上一步、下一步操作
- [ ] 配置游戏路径后，教程完成时保存路径到 config
- [ ] 设置页面有「查看教程」按钮，可重新打开教程
- [ ] 所有文本支持中英文国际化
- [ ] 样式与现代扁平设计保持一致

---

**计划完成并保存到 `docs/superpowers/plans/2026-04-03-tutorial-popup-plan.md`**