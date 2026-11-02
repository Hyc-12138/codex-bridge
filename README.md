# codex-bridge

一个 Claude Code skill：把有明确产物的活交给本机 Codex CLI 后台执行，Claude 只写任务书、跟进度、验收。

## 环境

- Windows + Git Bash
- 已登录的 [Codex CLI](https://github.com/openai/codex)
- Claude Code

## 安装

```bash
git clone https://github.com/Hyc-12138/codex-bridge ~/.claude/skills/codex-bridge
```

Codex CLI 不在 PATH 里时，把环境变量 `CODEX_BRIDGE_BIN` 设为它的完整路径。

## 使用

在 Claude Code 里说“走 Codex 桥”或“交给 Codex 跑”。流程和任务书要求见 [SKILL.md](SKILL.md)。

也可以直接跑脚本：

```bash
bash scripts/run.sh --cd <工作目录> --brief <任务书.md> [--report 报告.md] [--log codex_run.log]
bash scripts/status.sh <codex_run.log>
```

| 文件 | 作用 |
|---|---|
| `scripts/run.sh` | 预检沙箱权限，跑一次 `codex exec`，打印退出码、会话 id、用量和报告位置 |
| `scripts/status.sh` | 查看一次运行的进度 |
| `scripts/preflight.ps1` | 检查 Codex 沙箱能否给工作目录加权限，不通过时给出修复命令 |

## 许可

[Apache-2.0](LICENSE)
