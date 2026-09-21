# Codex Pulse

<p align="center">
  <img src="Sources/CodexPulse/Resources/pet-idle.png" width="320" alt="Codex Pulse desktop pet">
</p>

Codex Pulse 是一只原生 macOS Codex 桌面宠物。它会实时显示 Codex 周额度、重置时间和当日 Token；每轮任务结束后，小宠物会根据实际 Token 消耗做出反应，并飘出本轮数值。

## 特性

- 实时显示 Codex 周额度、Reserve 额度和重置时间
- 自动统计当日 Token，无需手工复制上下文
- 单次消耗、连击和额度恢复动作
- Token 扣量飘字会停留后再缓慢淡出
- 透明悬浮窗，可拖动、跨桌面，不占用 Dock
- 支持 macOS “减少动态效果”

## 系统要求

- macOS 14 或更高版本
- 已安装并登录 Codex 桌面应用或 Codex CLI
- Swift 6 工具链（仅源码构建需要）

## 构建与运行

```bash
git clone https://github.com/francoeur003/codex-pulse.git
cd codex-pulse
./scripts/build-app.sh
open "build/Codex Pulse.app"
```

构建完成后，可将 `build/Codex Pulse.app` 拖到“应用程序”。

## 交互

- 单击桌宠：展开或收起用量详情
- 拖动透明窗口：移动桌宠
- 悬停桌宠：显示退出按钮

## 数据与隐私

- 额度数据来自本机 Codex app-server 的 `account/rateLimits/read`
- 账户汇总来自 `account/usage/read`
- 今日与每轮 Token 仅解析本机 `~/.codex/sessions/YYYY/MM/DD/*.jsonl` 中的 `token_count` 事件
- 不读取消息正文，不上传数据，不读取或展示登录凭据

## 项目结构

```text
Sources/CodexPulse/        SwiftUI 源码与宠物资源
App/Info.plist             macOS 应用配置
scripts/build-app.sh       构建、签名和封装脚本
```
