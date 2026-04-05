# 下载管理页面优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化下载管理页面：实现上下可调分栏、暂停/继续/取消控制、历史项独立删除并可选删除本地文件、清空历史按钮、Windows下载成功通知

**Architecture:** 修改 modmanager.tscn 布局结构使用 VSplitContainer，扩展 download_tasks 数据结构支持暂停状态，实现 HTTP 断点续传，添加 Windows 系统通知

**Tech Stack:** Godot 4.5.1, GDScript, PowerShell, Windows API

---

## 文件结构

- **Modify**: `modmanager.tscn` - 下载管理标签页布局结构调整
- **Modify**: `modmanager.gd` - 下载逻辑扩展（暂停/继续、通知、历史删除）
- **Modify**: `locales/zh_CN.json` - 添加中文字符串
- **Modify**: `locales/en_US.json` - 添加英文字符串

---

## Task 1: 修改布局为 VSplitContainer 上下可调分栏

**Files:**
- Modify: `modmanager.tscn:327-380` - DownloadTab 结构

- [ ] **Step 1: 读取并理解当前 DownloadTab 结构**

```gdscript
# 当前结构 (lines 327-380):
[node name="DownloadTab" type="Control"]
  [node name="DownloadPanel"]
    [node name="DownloadVBox" type="VBoxContainer"]
      [node name="ActiveDownloadsSection"]
      [node name="HistorySection"]
```

- [ ] **Step 2: 将 DownloadVBox 从 VBoxContainer 改为 VSplitContainer**

将 `DownloadVBox` 节点的 `type` 从 `VBoxContainer` 改为 `VSplitContainer`，添加 `split_offset` 属性设置初始分割位置

- [ ] **Step 3: 调整子节点层级**

确保 ActiveDownloadsSection 作为上半部分，HistorySection 作为下半部分

- [ ] **Step 4: 提交更改**

```bash
git add modmanager.tscn
git commit -m "feat: 将下载管理页面改为VSplitContainer上下可调分栏"
```

---

## Task 2: 扩展 download_tasks 数据结构支持暂停功能

**Files:**
- Modify: `modmanager.gd:1614-1627` - download_tasks 数据结构

- [ ] **Step 1: 查看当前数据结构**

```gdscript
# 当前 (lines 1614-1627):
download_tasks[download_id] = {
    "mod_name": mod_name,
    "download_url": download_url,
    "status": "downloading",
    "progress": 0.0,
    "speed": "",
    "speed_bytes": 0,
    "save_path": "",
    "error": "",
    "start_time": Time.get_unix_time_from_system(),
    "total_size": 0,
    "downloaded_size": 0,
    "file_size": ""
}
```

- [ ] **Step 2: 扩展添加暂停相关字段**

在 `modmanager.gd` 的 `_create_download_task` 函数中，添加以下字段：
```gdscript
"temp_file_path": "",  # 临时文件路径，支持断点续传
"is_paused": false,    # 是否已暂停
"resume_url": "",      # 继续下载时的URL（带Range参数）
"bytes_downloaded": 0  # 已下载的字节数
```

- [ ] **Step 3: 提交更改**

```bash
git add modmanager.gd
git commit -m "feat: 扩展download_tasks数据结构支持暂停功能"
```

---

## Task 3: 实现暂停/继续/取消按钮UI

**Files:**
- Modify: `modmanager.gd:1676-1753` - _update_download_task_ui 函数

- [ ] **Step 1: 在任务项UI中添加暂停/继续和取消按钮**

修改 `_update_download_task_ui` 函数，在任务项的 HBox 中添加：
1. 暂停/继续按钮（图标切换）
2. 取消按钮

- [ ] **Step 2: 创建按钮处理函数**

添加 `_on_download_pause_pressed(download_id: String)` 函数：
```gdscript
func _on_download_pause_pressed(download_id: String) -> void:
    var task = download_tasks.get(download_id)
    if not task:
        return

    if task.get("is_paused", false):
        # 继续下载
        _resume_download(download_id)
    else:
        # 暂停下载
        _pause_download(download_id)
```

添加 `_on_download_cancel_pressed(download_id: String)` 函数：
```gdscript
func _on_download_cancel_pressed(download_id: String) -> void:
    # 停止下载监控
    _stop_progress_monitor(download_id)
    # 移除任务
    download_tasks.erase(download_id)
    # 更新UI
    _update_download_task_ui(download_id)
```

- [ ] **Step 3: 提交更改**

```bash
git add modmanager.gd
git commit -m "feat: 添加下载任务暂停/继续/取消按钮UI"
```

---

## Task 4: 实现暂停/继续逻辑（断点续传）

**Files:**
- Modify: `modmanager.gd` - 添加 _pause_download 和 _resume_download 函数

- [ ] **Step 1: 实现 _pause_download 函数**

```gdscript
func _pause_download(download_id: String) -> void:
    var task = download_tasks.get(download_id)
    if not task:
        return

    # 标记为暂停状态
    task["is_paused"] = true
    task["status"] = "paused"

    # 停止进度监控
    _stop_progress_monitor(download_id)

    # 更新UI显示暂停状态
    _update_download_task_ui(download_id)
```

- [ ] **Step 2: 实现 _resume_download 函数**

```gdscript
func _resume_download(download_id: String) -> void:
    var task = download_tasks.get(download_id)
    if not task:
        return

    # 恢复下载状态
    task["is_paused"] = false
    task["status"] = "downloading"

    # 获取已下载的字节数
    var bytes_downloaded = task.get("bytes_downloaded", 0)

    # 使用 HTTP Range 请求继续下载
    var download_url = task.get("download_url", "")
    var save_path = task.get("save_path", "")

    if bytes_downloaded > 0 and not download_url.is_empty():
        # 构造带 Range 的 URL
        var range_url = download_url
        if "?" in download_url:
            range_url += "&Range=bytes=%d-" % bytes_downloaded
        else:
            range_url += "?Range=bytes=%d-" % bytes_downloaded
        task["resume_url"] = range_url

    # 重新启动下载
    _download_mod_file(task.get("resume_url", download_url), save_path, task.get("mod_name", ""))

    # 更新UI
    _update_download_task_ui(download_id)
```

- [ ] **Step 3: 在下载监控中记录已下载字节数**

修改 `_check_download_progress` 函数，添加：
```gdscript
func _check_download_progress(abs_save_path: String, download_id: String, total_size: int) -> void:
    var task = download_tasks.get(download_id)
    if not task:
        return

    var file = FileAccess.open(abs_save_path, FileAccess.READ)
    if file:
        var downloaded_size = file.get_length()
        task["bytes_downloaded"] = downloaded_size
        file.close()
```

- [ ] **Step 4: 提交更改**

```bash
git add modmanager.gd
git commit -m "feat: 实现下载任务暂停/继续功能（断点续传）"
```

---

## Task 5: 添加历史项独立删除按钮和确认弹窗

**Files:**
- Modify: `modmanager.gd:1864-1918` - _update_download_history_ui 函数

- [ ] **Step 1: 在历史项UI中添加删除按钮**

修改 `_update_download_history_ui` 函数，在每个历史项末尾添加删除按钮：
```gdscript
# 在 hbox 末尾添加删除按钮
var delete_btn = Button.new()
delete_btn.text = "🗑️"
delete_btn.pressed.connect(_on_history_item_delete_pressed.bind(i))
hbox.add_child(delete_btn)
```

- [ ] **Step 2: 创建删除处理函数和确认弹窗**

添加 `_on_history_item_delete_pressed(index: int)` 函数：
```gdscript
func _on_history_item_delete_pressed(index: int) -> void:
    if index < 0 or index >= download_history.size():
        return

    var task = download_history[index]
    var mod_name = task.get("mod_name", "Unknown")

    # 创建确认弹窗
    _show_delete_history_confirm_dialog(index, mod_name)
```

添加 `_show_delete_history_confirm_dialog(index: int, mod_name: String)` 函数：
```gdscript
func _show_delete_history_confirm_dialog(index: int, mod_name: String) -> void:
    # 创建确认弹窗（使用已有的弹窗机制或新建）
    var confirm_dialog = ConfirmationDialog.new()
    confirm_dialog.title = translate("download_delete_title")
    confirm_dialog.dialog_text = translate("download_delete_confirm").format({"name": mod_name})

    # 添加"同时删除本地文件"复选框
    var checkbox = CheckBox.new()
    checkbox.text = translate("download_delete_file")
    confirm_dialog.add_child(checkbox)

    get_tree().root.add_child(confirm_dialog)
    confirm_dialog.popup_centered(Vector2(400, 200))

    # 连接确认按钮
    confirm_dialog.confirmed.connect(_on_history_delete_confirmed.bind(index, checkbox))
```

添加 `_on_history_delete_confirmed(index: int, checkbox: CheckBox)` 函数：
```gdscript
func _on_history_delete_confirmed(index: int, checkbox: CheckBox) -> void:
    if index < 0 or index >= download_history.size():
        return

    var task = download_history[index]

    # 如果勾选删除本地文件
    if checkbox.button_pressed:
        var file_path = task.get("save_path", "")
        if not file_path.is_empty() and FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(file_path)

    # 从历史中移除
    download_history.remove_at(index)

    # 保存到文件
    _save_download_history()

    # 更新UI
    _update_download_history_ui()
```

- [ ] **Step 3: 提交更改**

```bash
git add modmanager.gd
git commit -m "feat: 添加下载历史项独立删除按钮和确认弹窗"
```

---

## Task 6: 添加清空所有历史按钮

**Files:**
- Modify: `modmanager.tscn` - HistorySection 添加清空按钮
- Modify: `modmanager.gd` - 添加清空函数

- [ ] **Step 1: 在 tscn 中添加清空按钮**

在 HistorySection 的 HistoryLabel 旁边添加清空按钮：
```gdscript
[node name="ClearHistoryBtn" type="Button" parent="TabContainer/DownloadTab/DownloadPanel/DownloadVBox/HistorySection/HistoryLabel"]
layout_mode = 2
text = "清空历史"
```

- [ ] **Step 2: 在 gdscript 中添加清空函数**

在 modmanager.gd 中添加 `_on_clear_history_pressed` 函数：
```gdscript
func _on_clear_history_pressed() -> void:
    var confirm_dialog = ConfirmationDialog.new()
    confirm_dialog.title = translate("download_clear_all_title")
    confirm_dialog.dialog_text = translate("download_clear_all_confirm")

    get_tree().root.add_child(confirm_dialog)
    confirm_dialog.popup_centered(Vector2(400, 150))

    confirm_dialog.confirmed.connect(_on_clear_history_confirmed)
```

添加 `_on_clear_history_confirmed` 函数：
```gdscript
func _on_clear_history_confirmed() -> void:
    # 清空历史记录
    download_history.clear()

    # 保存到文件
    _save_download_history()

    # 更新UI
    _update_download_history_ui()
```

- [ ] **Step 3: 在 _init_download_ui 中连接信号**

```gdscript
var clear_history_btn = find_child_node(self, "ClearHistoryBtn")
if clear_history_btn:
    clear_history_btn.pressed.connect(_on_clear_history_pressed)
```

- [ ] **Step 4: 提交更改**

```bash
git add modmanager.tscn modmanager.gd
git commit -m "feat: 添加清空所有下载历史按钮"
```

---

## Task 7: 实现 Windows 下载成功通知

**Files:**
- Modify: `modmanager.gd` - 添加通知函数和调用

- [ ] **Step 1: 添加 Windows 通知函数**

在 modmanager.gd 中添加 `_show_windows_notification(title: String, message: String)` 函数：
```gdscript
func _show_windows_notification(title: String, message: String) -> void:
    # 使用 PowerShell 调用 Windows Toast 通知
    var ps_script = '''
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $template = @"
        <toast>
            <visual>
                <binding template="ToastGeneric">
                    <text>%s</text>
                    <text>%s</text>
                </binding>
            </visual>
        </toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("SlayTheSpire2ModManager").Show($toast)
    ''' % [title, message]

    # 转义引号
    ps_script = ps_script.replace('"', '\\"')

    # 执行 PowerShell
    OS.execute("powershell", ["-ExecutionPolicy", "Bypass", "-Command", ps_script], [], OS.EXEC_OUT_NULL)
```

- [ ] **Step 2: 在下载完成时调用通知**

在 `_on_async_download_complete` 函数中添加：
```gdscript
func _on_async_download_complete(download_id: String, mod_name: String, success: bool) -> void:
    # ... 现有逻辑 ...

    if success:
        # 显示 Windows 通知
        var title = translate("download_success_notice")
        var message = translate("download_complete").format({"name": mod_name})
        _show_windows_notification(title, message)
```

- [ ] **Step 3: 提交更改**

```bash
git add modmanager.gd
git commit -m "feat: 添加Windows下载成功通知功能"
```

---

## Task 8: 添加国际化字符串

**Files:**
- Modify: `locales/zh_CN.json` - 添加中文字符串
- Modify: `locales/en_US.json` - 添加英文字符串

- [ ] **Step 1: 添加中文翻译**

在 zh_CN.json 中添加：
```json
"download_pause": "暂停",
"download_resume": "继续",
"download_cancel": "取消",
"download_paused": "已暂停",
"download_clear_all": "清空历史",
"download_clear_all_title": "清空历史记录",
"download_clear_all_confirm": "确定要清空所有下载历史记录吗？",
"download_delete_title": "删除记录",
"download_delete_confirm": "确定要删除「%name」的下载记录吗？",
"download_delete_file": "同时删除本地文件",
"download_success_notice": "下载成功",
"download_complete": "%name 下载完成"
```

- [ ] **Step 2: 添加英文翻译**

在 en_US.json 中添加：
```json
"Pause": "Pause",
"download_resume": "Resume",
"download_cancel": "Cancel",
"download_paused": "Paused",
"download_clear_all": "Clear History",
"download_clear_all_title": "Clear History",
"download_clear_all_confirm": "Are you sure you want to clear all download history?",
"download_delete_title": "Delete Record",
"download_delete_confirm": "Delete download record for \"%name\"?",
"download_delete_file": "Also delete local file",
"download_success_notice": "Download Success",
"download_complete": "%name download complete"
```

- [ ] **Step 3: 提交更改**

```bash
git add locales/zh_CN.json locales/en_US.json
git commit -m "feat: 添加下载功能相关国际化字符串"
```

---

## Task 9: 测试和验证

**Files:**
- Test: 手动测试各项功能

- [ ] **Step 1: 测试上下分栏可调**

启动应用，切换到下载管理标签，拖拽分隔条验证上下分栏可自由调整

- [ ] **Step 2: 测试暂停/继续功能**

开始一个下载任务，点击暂停按钮，验证进度停止；点击继续按钮，验证从暂停处继续下载

- [ ] **Step 3: 测试取消功能**

开始下载后点击取消，验证任务被移除

- [ ] **Step 4: 测试历史删除功能**

在下载历史中点击删除按钮，验证弹出确认对话框；选择删除本地文件后验证文件和记录都被删除

- [ ] **Step 5: 测试清空历史功能**

点击清空历史按钮，验证弹出确认对话框；确认后验证所有历史记录被清空

- [ ] **Step 6: 测试下载成功通知**

完成一个下载任务，验证 Windows 系统通知中心弹出下载成功通知

- [ ] **Step 7: 提交最终版本**

```bash
git add .
git commit -m "feat: 完成下载管理页面优化所有功能"
```

---

## 执行选项

**Plan complete and saved to `docs/superpowers/plans/2026-04-01-download-page-optimization-plan.md`. Two execution options:**

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**