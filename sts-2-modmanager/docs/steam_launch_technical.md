# Steam启动游戏技术方案

## 概述
通过Steam协议启动Slay the Spire 2，避免"未使用Steam打开"的错误提示。

## 技术原理

### Steam协议
- **协议格式**: `steam://rungameid/{AppID}`
- **Slay the Spire 2 AppID**: `2868840`
- **完整URL**: `steam://rungameid/2868840`

### 工作原理
1. 调用Steam协议URL会通知Steam客户端
2. Steam客户端验证游戏安装状态
3. Steam以正确的环境变量和权限启动游戏
4. 游戏检测到Steam环境，不会报"未使用Steam打开"错误

## Godot实现方案

### 核心方法
```gdscript
# 使用OS.shell_open()打开Steam协议
OS.shell_open("steam://rungameid/2868840")
```

### 实现代码示例

```gdscript
# launch_game.gd - 游戏启动管理脚本

# Steam App ID for Slay the Spire 2
const STEAM_APP_ID := "2868840"

# 启动模式枚举
enum LaunchMode { VANILLA, MODDED, MULTIPLAYER }

func launch_game(mode: LaunchMode) -> void:
    var steam_url := ""
    
    match mode:
        LaunchMode.VANILLA:
            # 原版启动 - 使用基础Steam协议
            steam_url = "steam://rungameid/%s" % STEAM_APP_ID
        LaunchMode.MODDED:
            # 模组启动 - 可能需要额外参数
            steam_url = "steam://rungameid/%s" % STEAM_APP_ID
        LaunchMode.MULTIPLAYER:
            # 联机启动 - 使用launch协议以显示启动选项
            steam_url = "steam://launch/%s/dialog" % STEAM_APP_ID
    
    # 执行启动
    var error := OS.shell_open(steam_url)
    if error != OK:
        push_error("Failed to launch game via Steam: %s" % error)
        # 可以显示错误提示给用户
```

### Steam协议类型

| 协议 | 格式 | 说明 |
|------|------|------|
| rungameid | `steam://rungameid/{AppID}` | 直接运行游戏 |
| launch | `steam://launch/{AppID}/[option]` | 运行游戏并显示选项 |
| run | `steam://run/{AppID}/[args]` | 运行游戏并传递参数 |

**推荐使用 `steam://launch/` 协议**，因为它会尊重Steam的启动选项设置。

## 注意事项

### 1. Steam客户端状态
- Steam必须已安装且正在运行
- 如果Steam未运行，协议会先启动Steam再启动游戏

### 2. 游戏安装检测
- 游戏必须已在Steam中安装
- 未安装时Steam会显示安装提示

### 3. 启动参数
- `steam://rungameid/` 会忽略Steam设置的启动参数
- `steam://launch/` 会使用Steam设置的启动参数
- 推荐使用 `steam://launch/{AppID}/dialog` 显示启动选项对话框

### 4. 错误处理
```gdscript
func launch_game_safe(mode: LaunchMode) -> bool:
    var steam_url := "steam://launch/%s/dialog" % STEAM_APP_ID
    
    var error := OS.shell_open(steam_url)
    if error != OK:
        # 显示错误通知
        show_notification(translate("launch_failed"), "error")
        return false
    
    # 显示成功通知
    show_notification(translate("launching_game"), "info")
    return true
```

## 实现建议

### 1. 启动按钮信号处理
```gdscript
# 在launch_button.gd中
signal launch_mode_pressed(mode: String)

func _on_vanilla_pressed():
    launch_mode_pressed.emit("vanilla")
    
func _on_modded_pressed():
    launch_mode_pressed.emit("modded")
    
func _on_multiplayer_pressed():
    launch_mode_pressed.emit("multiplayer")
```

### 2. 主控制器接收信号
```gdscript
# 在modmanager.gd中
func _ready():
    # 连接启动按钮信号
    launch_button.launch_mode_pressed.connect(_on_launch_game)

func _on_launch_game(mode: String):
    match mode:
        "vanilla":
            GameLauncher.launch_vanilla()
        "modded":
            GameLauncher.launch_modded()
        "multiplayer":
            GameLauncher.launch_multiplayer()
```

### 3. 创建游戏启动工具类
```gdscript
# utils/game_launcher.gd
class_name GameLauncher
extends RefCounted

const STEAM_APP_ID := "2868840"

static func launch_vanilla() -> bool:
    return _launch_steam_game()

static func launch_modded() -> bool:
    return _launch_steam_game()

static func launch_multiplayer() -> bool:
    return _launch_steam_game("dialog")

static func _launch_steam_game(option: String = "") -> bool:
    var url := "steam://launch/%s" % STEAM_APP_ID
    if not option.is_empty():
        url += "/%s" % option
    
    var error := OS.shell_open(url)
    return error == OK
```

## 测试要点

1. **Steam运行状态测试**
   - Steam已运行时启动游戏
   - Steam未运行时启动游戏（会先启动Steam）

2. **游戏安装状态测试**
   - 游戏已安装时正常启动
   - 游戏未安装时显示安装提示

3. **不同启动模式测试**
   - 原版启动
   - 模组启动
   - 联机启动

4. **错误处理测试**
   - 无效的AppID
   - Steam协议不支持的系统（非Windows/Mac/Linux）

## 参考资料

- [Steam Browser Protocol](https://developer.valvesoftware.com/wiki/Steam_browser_protocol)
- [Godot OS.shell_open Documentation](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-shell-open)
- [Slay the Spire 2 Steam页面](https://store.steampowered.com/app/2868840/Slay_the_Spire_2/)

---

*文档创建时间: 2026-03-26*
*适用版本: Godot 4.5.1*
