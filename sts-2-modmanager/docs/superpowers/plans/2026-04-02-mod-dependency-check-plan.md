# 模组依赖检测功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为模组管理页面添加依赖检测和刷新模组列表功能。当模组缺少依赖时，在详情面板显示缺少的依赖名称，并在列表项上用红色背景标注。

**架构：** 在 load_mods() 流程末尾调用依赖检测函数，遍历所有模组的 dependencies 字段，检查是否有所需依赖已安装。视觉标注使用优先级逻辑（红色 > 黄色）。

**技术栈：** Godot 4.5.1, GDScript

---

## 文件结构

- **修改**: `ui/mod_item.gd` - 添加 missing_dependencies 处理和视觉标注逻辑
- **修改**: `modmanager.gd` - 添加 _check_mod_dependencies() 函数，在 load_mods() 末尾调用，在 _show_mod_details() 中显示缺少依赖
- **修改**: `modmanager.tscn` - 在工具栏添加刷新按钮（或复用现有按钮）

---

## 实现任务

### Task 1: 修改 mod_item.gd 添加视觉标注逻辑

**Files:**
- Modify: `ui/mod_item.gd:1-153`

- [ ] **Step 1: 添加 missing_dependencies 变量**

在第17行后添加：
```gdscript
var missing_dependencies: Array = []  # 缺少的依赖列表
```

- [ ] **Step 2: 修改 setup() 函数中的背景颜色逻辑**

修改第65-76行的代码，将：
```gdscript
# 设置下载来源背景色（仅作为背景标识）
var download_source = data.get("download_source", "")
if not download_source.is_empty() and (download_source == "nexus" or download_source == "nexusmods"):
    # 该项背景设为淡黄色
    if bg_color:
        bg_color.color = Color(1.0, 0.95, 0.6, 0.15)  # 淡黄色背景
```

改为：
```gdscript
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
```

- [ ] **Step 3: 修改 set_selected() 函数中的背景颜色逻辑**

修改第121-138行的 set_selected() 函数，添加优先级逻辑：
```gdscript
func set_selected(selected: bool) -> void:
    is_selected = selected
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
```

---

### Task 2: 在 modmanager.gd 中添加依赖检测函数

**Files:**
- Modify: `modmanager.gd:5121-5200`

- [ ] **Step 1: 添加 _check_mod_dependencies() 函数**

在 modmanager.gd 中找一个合适的位置（推荐在 load_mods() 函数之后），添加：
```gdscript
# 检测模组依赖是否满足
func _check_mod_dependencies() -> void:
    print("=== 开始检测模组依赖 ===")
    # 构建已安装模组ID集合
    var installed_ids: Array = []
    for mod in mods:
        var mod_id = mod.get("id", "")
        if not mod_id.is_empty():
            installed_ids.append(mod_id)

    print("已安装模组ID: ", installed_ids)

    # 遍历每个模组，检查依赖
    for mod in mods:
        var deps = mod.get("dependencies", [])
        var missing: Array = []

        for dep_id in deps:
            if dep_id not in installed_ids:
                missing.append(dep_id)

        mod["missing_dependencies"] = missing
        if not missing.is_empty():
            print("模组 %s 缺少依赖: %s" % [mod.get("name", ""), missing])

    print("=== 依赖检测完成 ===")
```

- [ ] **Step 2: 在 load_mods() 末尾调用依赖检测**

找到 load_mods() 函数，在 `_refresh_mod_list_display()` 调用之后（或函数末尾），添加：
```gdscript
    # 检测模组依赖
    _check_mod_dependencies()

    print("=== load_mods 完成 ===")
```

---

### Task 3: 在详情面板显示缺少依赖信息

**Files:**
- Modify: `modmanager.tscn` - 在 DetailsVBox 添加 DepLabel
- Modify: `modmanager.gd` - 添加变量引用和显示逻辑

- [ ] **Step 1: 在 tscn 中添加依赖显示 Label**

在 `modmanager.tscn` 的 ModDetailsPanel/DetailsVBox 中，在 DescLabel (第206-211行) 之后添加：
```
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_dep"]
bg_color = Color(0.9, 0.2, 0.2, 0.15)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4
```

然后在 DescLabel 节点之后添加：
```
[node name="DepLabel" type="Label" parent="TabContainer/ModTab/HSplit/RightPanel/ModDetailsPanel/DetailsVBox"]
layout_mode = 2
size_flags_horizontal = 3
text = "依赖: "
visible = false
```

- [ ] **Step 2: 在 modmanager.gd 中添加变量引用**

在变量声明区域（大约第245行后）添加：
```gdscript
@onready var mod_details_dep: Label
```

在初始化代码中（大约第1377行附近）添加查找：
```gdscript
mod_details_dep = find_child_node(self, "DepLabel")
```

- [ ] **Step 3: 在 _show_mod_details() 中显示依赖信息**

在 mod_details_desc 显示之后（第7353行附近）添加：
```gdscript
    # 显示缺少依赖
    var missing_deps = mod_data.get("missing_dependencies", [])
    if mod_details_dep:
        if not missing_deps.is_empty():
            var dep_text = "缺少依赖: " + ", ".join(missing_deps)
            mod_details_dep.text = dep_text
            mod_details_dep.visible = true
            # 设置红色文字
            mod_details_dep.add_theme_color_override("font_color", Color("#ff5555"))
        else:
            mod_details_dep.visible = false
```

---

### Task 4: 添加刷新按钮到模组页面

**Files:**
- Modify: `modmanager.tscn` - 在 TopBar 添加刷新按钮
- Modify: `modmanager.gd` - 添加刷新按钮功能

- [ ] **Step 1: 在 tscn 中添加刷新按钮**

在 `modmanager.tscn` 的 TabContainer/ModTab/TopBar 中，在现有按钮之后添加。找到最后一个按钮节点（比如 BatchUninstallBtn），在其后添加：
```
[node name="RefreshModsBtn" type="Button" parent="TabContainer/ModTab/TopBar"]
layout_mode = 2
size_flags_vertical = 1
text = "刷新"
```

- [ ] **Step 2: 在 modmanager.gd 中添加按钮引用和功能**

在变量声明区域（大约第245行后）添加：
```gdscript
@onready var refresh_mods_button: Button
```

在初始化代码中（大约第1365行附近）添加查找和信号连接：
```gdscript
refresh_mods_button = find_child_node(self, "RefreshModsBtn")
if refresh_mods_button:
    refresh_mods_button.pressed.connect(_on_refresh_mods_pressed)
    refresh_mods_button.text = translate("refresh")
```

添加按钮回调函数（在 modmanager.gd 末尾或合适位置）：
```gdscript
# 刷新模组列表
func _on_refresh_mods_pressed() -> void:
    print("=== 刷新模组列表 ===")
    load_mods()
```

- [ ] **Step 3: 在 locales 中添加刷新文本**

在 `locales/zh_CN.json` 中添加：
```json
"refresh": "刷新"
```

在 `locales/en_US.json` 中添加：
```json
"refresh": "Refresh"
```

---

### Task 5: 添加刷新文本到 locales

**Files:**
- Modify: `locales/zh_CN.json`
- Modify: `locales/en_US.json`

- [ ] **Step 1: 在中文 locale 中添加**

在 `locales/zh_CN.json` 中添加：
```json
"refresh": "刷新"
```

- [ ] **Step 2: 在英文 locale 中添加**

在 `locales/en_US.json` 中添加：
```json
"refresh": "Refresh"
```

---

### Task 6: 测试验证

**Files:**
- 无（手动测试）

- [ ] **Step 1: 安装有依赖的模组**

安装一个带有 dependencies 字段的模组（如 Lemon Spire 2 依赖 BaseLib）。

- [ ] **Step 2: 验证红色标注**

检查模组列表项是否显示淡红色背景。

- [ ] **Step 3: 验证详情面板显示**

检查详情面板是否显示"缺少依赖: xxx"。

- [ ] **Step 4: 安装依赖模组后刷新**

安装依赖模组，点击刷新按钮，验证红色消失。

- [ ] **Step 5: 验证优先级**

同时有 N 网来源和缺少依赖时，验证红色优先。

---

## 注意事项

1. Task 3 中需要确认详情面板是否有可用的 Label 节点来显示依赖信息，如果没有需要先在 tscn 中添加。

2. Task 4 中如果无法找到合适的现有按钮，可能需要在 tscn 中添加新的刷新按钮节点。

3. 刷新功能可以直接调用 load_mods() 函数，它会执行完整的依赖检测流程。