# 下载管理页面优化设计

**日期**: 2026-04-01

## 1. 需求概述

优化下载管理页面的操作功能，提升用户体验。

## 2. 具体需求

### 2.1 分栏调整
- 将当前的上下固定分栏改为可自由调整的上下分栏
- 使用 Godot 的 `VSplitContainer` 实现拖拽调整分隔位置

### 2.2 当前下载任务控制
- **暂停/开始功能**：支持断点续传，暂停后可以继续下载而不重新开始
- **取消功能**：停止并移除下载任务

### 2.3 下载历史功能
- 每个下载历史项添加独立的删除按键
- 删除时弹出确认对话框，询问是否一并删除本地下载文件
- 添加"清除所有下载历史"按钮

### 2.4 下载成功通知
- 下载完成后发送 Windows 系统通知中心弹窗
- 使用 Godot 的 `OS.notification` 或 Windows API 实现

## 3. 技术方案

### 3.1 布局调整
- 修改 `modmanager.tscn` 中 DownloadTab 的结构
- 将 `DownloadVBox` 改为 `VSplitContainer`
- 上半部分：当前下载任务列表
- 下半部分：下载历史列表

### 3.2 下载任务数据结构扩展
```gdscript
download_tasks[download_id] = {
    "mod_name": mod_name,
    "download_url": download_url,
    "status": "downloading",  # downloading, paused, completed, failed
    "progress": 0.0,
    "speed": "",
    "speed_bytes": 0,
    "save_path": "",
    "error": "",
    "start_time": Time.get_unix_time_from_system(),
    "total_size": 0,
    "downloaded_size": 0,
    "file_size": "",
    "temp_file_path": "",  # 临时文件路径，支持断点续传
    "is_paused": false     # 是否已暂停
}
```

### 3.3 暂停/继续实现
- 暂停时保存当前下载进度和临时文件路径
- 继续时从临时文件位置开始下载
- 使用 HTTP Range 请求实现断点续传

### 3.4 Windows 通知
- 使用 `DisplayServer.notification` 或 PowerShell 调用 Windows Toast 通知

## 4. 界面设计

### 4.1 当前下载任务项
```
[↓] [模组名称                    ] [暂停] [取消]
    [████████████░░░░░░░░░░░░░░░] 50%  1.2MB/s  5.2MB/10MB
```

### 4.2 下载历史项
```
[✓] [模组名称                    ] [2026-04-01 10:30] [🗑️删除]
```

### 4.3 分栏布局
```
+------------------------------------------+
|  下载管理                                |
+--------------------+---------------------+
| 当前下载            | 下载历史    [清空全部]|
+--------------------+---------------------+
| [下载任务项1]       | [历史项1]  [删除]   |
| [下载任务项2]       | [历史项2]  [删除]   |
|                    |                     |
| <--- 可拖拽调整 ---> |                     |
|                    |                     |
+--------------------+---------------------+
```

## 5. 国际化支持

需要添加以下翻译key：
- `download_pause`: 暂停
- `download_resume`: 继续
- `download_cancel`: 取消
- `download_clear_all`: 清空历史
- `download_delete_confirm`: 确定删除此下载记录？
- `download_delete_file`: 同时删除本地文件
- `download_success_notice`: 下载成功
- `download_complete`: 下载完成