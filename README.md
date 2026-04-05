# 🎮 STS2 模组管理器介绍

> 一款专为游戏模组管理与存档维护打造的集成工具，旨在提供从模组安装、合规校验到存档管理、联机补丁注入的全流程解决方案。只需配置游戏可执行文件路径与N网API密钥，即可体验高度自动化的模组生命周期管理。

---

## ✨ 核心功能概览

### 一、📦 模组管理

- 🔍 **合规性检验**：自动检测模组文件结构、格式及内容是否符合规范，避免因模组错误导致游戏崩溃。  
- 🔗 **依赖关系检查**：解析模组间的依赖树，缺失前置模组时给出明确提示，确保模组正确加载。  
- 🏷️ **分标签启用与预设**：支持为模组自定义标签（如“玩法扩展”“画质优化”），并可保存为预设方案，一键切换不同模组组合。

### 二、💾 存档管理

- 📋 **存档详情查看**：展示存档的创建时间、游戏进度、角色信息等元数据。  
- 🔄 **导入/导出/覆盖**：支持存档文件的备份、迁移与替换，便于多设备同步或回滚进度。

### 三、🌐 N网深度集成

- ⚡ **一键下载安装**：通过配套网页插件，在Nexus Mods页面直接触发下载并自动安装至管理器。  
- 🚀 **未来更新检测**（待实现版本）：自动比对已安装模组与N网最新版本，提示或一键更新。

### 四、🔧 学习版联机补丁工具

- 🧩 **自动注入与恢复**：启动游戏前自动注入联机补丁，游戏结束后恢复原始文件，无需手动干预，保障学习版联机功能与游戏完整性。

### 五、📖 用户引导与配置

- 🎓 **内置使用教程**：每一步操作均有文字指引，降低上手门槛。  
- ⚙️ **极简配置**：仅需提供两项内容——游戏主程序（`.exe`）路径、N网API密钥（用于接口调用），其余自动完成。

---

## 💡 技术亮点

- 🌉 **插件化网页集成**：实现浏览器与本地管理器的无缝通信。  
- 🛡️ **安全补丁注入**：采用临时文件替换机制，退出游戏自动还原，无残留风险。

---

## 👥 适用人群

- 🎲 **模组重度玩家**：需要批量管理、频繁切换模组配置。  
- 🤝 **学习版联机用户**：希望自动化处理补丁注入与恢复。  
- 🗃️ **存档收藏家**：需要跨设备同步或精细管理多个进度。

---

## 🗺️ 未来路线图

- ✅ 模组版本更新检查与一键升级  
- 🌍 支持更多模组源（如Mod DB、Steam创意工坊映射）

---

> 💬 **让模组管理回归简单——您只负责游戏，剩下的交给管理器。**

*—— 作者：ckcc_baize*

# 🎮 STS2 Mod Manager Introduction

> An all-in-one tool designed for game mod management and save file maintenance, covering the entire workflow from mod installation and compliance checking to save management and online fix injection. Simply configure your game executable path and Nexus Mods API key, and enjoy a highly automated mod lifecycle management experience.

---

## ✨ Core Features Overview

### I. 📦 Mod Management

- 🔍 **Compliance Check**: Automatically verifies whether the mod's file structure, format, and content meet the required specifications, preventing game crashes caused by faulty mods.
- 🔗 **Dependency Check**: Parses the dependency tree between mods; if a required mod is missing, it provides clear prompts to ensure proper mod loading.
- 🏷️ **Tag-based Activation & Presets**: Supports custom tags for mods (e.g., "Gameplay Expansion", "Graphics Overhaul") and allows saving them as presets for one‑click switching between different mod configurations.

### II. 💾 Save Management

- 📋 **Save Details View**: Displays metadata such as creation time, game progress, character information, etc.
- 🔄 **Import / Export / Overwrite**: Supports backup, migration, and replacement of save files, making it easy to sync across devices or roll back progress.

### III. 🌐 Nexus Mods Deep Integration

- ⚡ **One‑Click Download & Install**: Through the companion web plugin, you can trigger downloads directly from Nexus Mods pages and automatically install them into the manager.
- 🚀 **Future Update Detection** (coming soon): Automatically compares installed mods with the latest versions on Nexus Mods, notifying you or allowing one‑click updates.

### IV. 🔧 Online Fix Tool for Non‑Legit Copies

- 🧩 **Auto‑injection & Restoration**: Automatically injects the online fix before launching the game, and restores the original files after the game exits – no manual intervention required, ensuring both online functionality and game integrity.

### V. 📖 User Guidance & Configuration

- 🎓 **Built‑in Tutorial**: Step‑by‑step text guidance for every operation, lowering the learning curve.
- ⚙️ **Minimal Configuration**: Only two things are required – the path to the game executable (`.exe`) and your Nexus Mods API key. Everything else is handled automatically.

---

## 💡 Technical Highlights

- 🌉 **Plugin‑based Web Integration**: Enables seamless communication between your browser and the local manager.
- 🛡️ **Safe Patch Injection**: Uses a temporary file replacement mechanism; files are automatically restored when the game exits, leaving no residue.

---

## 👥 Target Audience

- 🎲 **Heavy Mod Users**: Need batch management and frequent switching of mod configurations.
- 🤝 **Online Fix Users** (non‑legit copies): Want automated handling of patch injection and restoration.
- 🗃️ **Save Collectors**: Need to sync saves across devices or manage multiple progress files with fine control.

---

## 🗺️ Roadmap

- ✅ Mod version update check & one‑click upgrade
- 🌍 Support for more mod sources (e.g., Mod DB, Steam Workshop mapping)

---

> 💬 **Keep mod management simple – you focus on the game, leave the rest to the manager.**

*— Author: ckcc_baize*
