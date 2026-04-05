# 模组依赖检测功能设计

## 概述

为模组管理页面添加依赖检测和刷新模组列表功能。当已安装的模组 JSON 中包含 `dependencies` 字段且有内容时，检测是否有所需依赖已安装。如果缺少依赖，在详情面板中显示缺少的依赖名称，并在列表项上用红色背景标注。

## 需求

1. **依赖检测**：读取每个已安装模组 JSON 中的 `dependencies` 字段
2. **匹配逻辑**：严格 ID 匹配（检查 dependencies 数组中的值是否与已安装模组的 id 匹配）
3. **详情标注**：缺少依赖时，在详情面板显示缺少的依赖名
4. **视觉标注**：
   - N网来源 → 标黄（淡黄色背景）
   - 缺少依赖 → 标红（淡红色背景）
   - **优先级**：同时满足时，优先显示红色
5. **刷新恢复**：刷新模组列表后重新检测依赖状态，正确则取消红色标注

## 数据结构

### 运行时模组数据

在 `mods` 数组元素中增加字段：
```gdscript
{
  "id": "lemonSpire2",
  "name": "Lemon Spire 2",
  "dependencies": ["BaseLib"],
  "missing_dependencies": [],  # 运行时新增，缺少的依赖ID列表
  "download_source": "nexus",
  ...
}
```

### mod_item.gd

新增变量：
```gdscript
var missing_dependencies: Array = []  # 缺少的依赖列表
```

## 依赖检测逻辑

### 函数：_check_mod_dependencies()

位置：modmanager.gd

```gdscript
func _check_mod_dependencies() -> void:
    # 构建已安装模组ID集合
    var installed_ids: Array = []
    for mod in mods:
        var mod_id = mod.get("id", "")
        if not mod_id.is_empty():
            installed_ids.append(mod_id)

    # 遍历每个模组，检查依赖
    for mod in mods:
        var deps = mod.get("dependencies", [])
        var missing: Array = []

        for dep_id in deps:
            if dep_id not in installed_ids:
                missing.append(dep_id)

        mod["missing_dependencies"] = missing
        print("模组 %s 缺少依赖: %s" % [mod.get("name", ""), missing])
```

### 调用时机

1. `load_mods()` 末尾
2. 刷新按钮点击时

## 视觉标注逻辑

### mod_item.gd - setup() 函数

修改现有逻辑，红色优先于黄色：

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
        bg_color.color = Color(1.0, 0.95, 0.6, 0.15)  # 淡黄色
```

### mod_item.gd - set_selected() 函数

同样应用优先级逻辑：

```gdscript
func set_selected(selected: bool) -> void:
    is_selected = is_selected
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

## 详情面板显示

### modmanager.gd - _show_mod_details() 函数

在现有来源显示之后，新增依赖信息显示。

需要检查现有的详情面板结构，确定添加位置。预期效果：
- 如果缺少依赖，显示"缺少依赖: xxx, yyy"（红色文字）
- 如果依赖已满足，不显示依赖相关信息（或显示绿色"依赖已满足"）

## 刷新按钮

### 位置

模组页面工具栏，搜索框旁边或模组列表顶部。

### 功能

- 调用 `load_mods()` 重新加载模组
- 触发依赖检测
- 更新所有列表项的视觉标注

### UI 文本

- 中文：刷新
- 英文：Refresh

## 实现步骤

1. **修改 mod_item.gd**
   - 添加 missing_dependencies 变量
   - 修改 setup() 函数中的背景颜色逻辑
   - 修改 set_selected() 函数中的背景颜色逻辑

2. **修改 modmanager.gd**
   - 添加 `_check_mod_dependencies()` 函数
   - 在 `load_mods()` 末尾调用依赖检测

3. **修改 _show_mod_details()**
   - 添加缺少依赖的显示逻辑

4. **添加刷新按钮**
   - 在模组页面添加工具栏按钮
   - 连接点击事件到 load_mods()

5. **测试验证**
   - 安装有依赖的模组，验证红色标注显示
   - 安装依赖模组后刷新，验证红色消失
   - 同时有 N 网来源和缺少依赖，验证红色优先