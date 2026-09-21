# Codex Pulse

<p align="center">
  <img src="docs/images/codex-pulse-hero.png" width="100%" alt="Codex Pulse 桌面宠物与用量监控功能总览">
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-111827?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-6D5DFB">
  <img alt="Privacy" src="https://img.shields.io/badge/数据-仅本机-16A05D">
</p>

<p align="center">
  <a href="#快速开始"><strong>快速开始</strong></a>
  · <a href="#动画状态">查看动画</a>
  · <a href="#数据与隐私">数据边界</a>
  · <a href="#关于作者">关于作者</a>
</p>

## 把抽象 Token 变成桌面反馈

Codex Pulse 是一款原生 macOS 桌面小工具。它连接本机 Codex app-server 获取周额度和重置时间，同时监听当日 Codex session 里的 `token_count` 事件。每轮任务结束后，它会直接飘出本轮 Token 数值，并根据消耗强度切换小宠物状态。

| 能力 | 你能看到什么 |
| --- | --- |
| Codex 周额度 | 已用/剩余百分比与下次重置时间 |
| Reserve 额度 | 点击小宠物后展开详情 |
| 今日 Token | 自动汇总当天所有本机 Codex 会话 |
| 每轮消耗 | 以 `−47.4K tok` 形式停留后再上浮淡出 |
| 连续消耗 | 短时间内多次事件或大消耗会触发连击动作 |
| 额度恢复 | 检测到用量周期重置时切换恢复状态 |

## 动画状态

<table>
  <tr>
    <td align="center"><img src="Sources/CodexPulse/Resources/pet-idle.png" width="190" alt="待机"><br><b>待机</b><br><sub>缓慢呼吸，保持安静</sub></td>
    <td align="center"><img src="Sources/CodexPulse/Resources/pet-hit.png" width="190" alt="单次消耗"><br><b>单次消耗</b><br><sub>每轮 Token 结算后反馈</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="Sources/CodexPulse/Resources/pet-combo.png" width="190" alt="连击"><br><b>连击</b><br><sub>连续事件或高 Token 消耗</sub></td>
    <td align="center"><img src="Sources/CodexPulse/Resources/pet-recover.png" width="190" alt="额度恢复"><br><b>额度恢复</b><br><sub>额度重置后恢复精神</sub></td>
  </tr>
</table>

### “命中 / 未命中”是什么？

这不是请求成功或失败。在支持 Prompt Cache 的模型计量里：

- **缓存命中**：输入内容从已有缓存中读取，对应 Codex 事件里的 `cached_input_tokens`。
- **缓存未命中**：这次需要新处理的输入，可由 `input_tokens - cached_input_tokens` 得到。
- **输出**：模型新生成的 `output_tokens`。

Codex Pulse 当前稳定版先展示每轮总 Token，不会把“缓存未命中”误表达成任务失败。

## 快速开始

### 系统要求

- macOS 14 或更高版本
- 已安装并登录 Codex 桌面应用或 Codex CLI
- Swift 6 工具链（仅源码构建需要）

### 从源码构建

```bash
git clone https://github.com/francoeur003/codex-pulse.git
cd codex-pulse
./scripts/build-app.sh
open "build/Codex Pulse.app"
```

构建完成后，可将 `build/Codex Pulse.app` 拖到“应用程序”。

> 当前构建使用本地 ad-hoc 签名，未经 Apple 公证。

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
docs/                      项目图片与参考资料
```

---

<!-- abo-douyin-profile:start -->
## 关于作者

<p align="center">
  <strong>阿波 Nate</strong><br>
  抖音号：<code>53691197416</code>
</p>

<p align="center">
  <img src="docs/images/douyin-abo-nate.jpg" width="320" alt="阿波 Nate 抖音二维码，抖音号 53691197416">
</p>
<!-- abo-douyin-profile:end -->
