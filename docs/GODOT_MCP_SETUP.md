# Godot MCP 接入说明

本项目已按 `tugcantopaloglu/godot-mcp` 配置 MCP。

## 本地安装

MCP server 安装在本机 `.tools/godot-mcp`，该目录已被 `.gitignore` 忽略，不会提交到仓库。

如果换机器或重新 checkout，需要重新安装：

```powershell
git clone --depth 1 https://github.com/tugcantopaloglu/godot-mcp.git .tools/godot-mcp
npm install --prefix .tools/godot-mcp
npm run build --prefix .tools/godot-mcp
```

项目 MCP 配置指向：

- `.tools/godot-mcp/build/index.js`
- `.tools/godot-4.2.2/Godot_v4.2.2-stable_win64.exe`

## 运行时 Autoload

`game_*` 运行时工具需要 Godot 项目启动 `McpInteractionServer`。

本项目已注册：

```ini
McpInteractionServer="*res://tools/McpInteractionServer.gd"
```

游戏运行时，该 server 会监听 `127.0.0.1:9090`。
