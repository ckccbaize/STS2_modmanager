# 教程弹窗设计

## 功能概述

首次启动时显示分步向导式教程，引导用户完成初始配置并介绍核心功能。

## 首次启动判断

- 时机：`_ready()` → `load_config()` 后检查 `game_path` 是否为空
- 若为空（未配置游戏路径），显示教程弹窗
- 教程完成后，将 game_path 持久化到 config，弹窗不再显示

## 教程内容（5步）

| 步骤 | 标题 | 内容 |
|------|------|------|
| 1 | 欢迎使用 | 简短欢迎词 + "下一步"按钮 |
| 2 | 配置游戏路径 | 引导用户选择 `SlayTheSpire2.exe`，自动检测路径 |
| 3 | 模组管理简介 | 介绍模组列表、启用/禁用、拖放安装 |
| 4 | 存档管理简介 | 介绍存档列表、备份、导入/导出 |
| 5 | Nexus 模组下载 | 介绍浏览器扩展 + 文件目录下载按钮的工作流程 |

## UI 设计（居中向导式）

- **尺寸**：480 x 360 像素，居中弹出
- **结构**：
  - 顶部：步骤指示器（圆点 1/5, 2/5...）
  - 中部：标题 + 内容区域（文字 + 必要时图示）
  - 底部：按钮行（跳过/上一步/下一步→完成）
- **样式**：与现有 UI 保持一致（现代扁平设计）
- **交互**：
  - 点击"跳过"直接关闭教程
  - 支持键盘方向键切换

## 设置页面教程入口

- 位置：设置标签页底部
- 样式：普通按钮，显示文字如"查看教程"
- 点击后重新打开教程弹窗（不检查 game_path）

## 实现要点

1. **配置持久化**：教程完成后不设置标志位，依靠 game_path 是否配置来判断
2. **浏览器扩展通信**：管理器启动本地 HTTP 服务器，监听端口接收扩展发送的下载链接
3. **国际化**：所有教程文本通过 `translate()` 获取，支持中英文

## 数据流

```
_ready()
  → load_config()
    → if game_path == "":
        → show_tutorial_popup()
          → 用户完成配置或跳过
            → 保存 game_path 到 config
            → 下次启动不再显示
```

## 需添加的国际化字段

- `tutorial_welcome_title`, `tutorial_welcome_content`
- `tutorial_game_path_title`, `tutorial_game_path_content`
- `tutorial_mods_title`, `tutorial_mods_content`
- `tutorial_saves_title`, `tutorial_saves_content`
- `tutorial_nexus_title`, `tutorial_nexus_content`
- `tutorial_skip`, `tutorial_prev`, `tutorial_next`, `tutorial_finish`
- `tutorial_button` (设置页按钮)