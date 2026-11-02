---
name: codex-bridge
description: 把有明确产物和完成标准的活交给本机 Codex CLI 后台执行（默认 gpt-6.1-sol，effort xhigh），Claude 只写任务书、跟进度、验收。用于「走 Codex 桥」「交给 Codex 跑」「用桥跑这个大项」「codex exec」等场景。写任务书和验收比活本身还费 token 的不走桥。
---

# Codex 桥

桥就是本机的 Codex 命令行。脚本优先用环境变量 `CODEX_BRIDGE_BIN` 指定的路径，没有就在 PATH 里找 `codex.cmd`、`codex`。默认模型 `gpt-6.1-sol`、effort `xhigh`，要换用 `--model`、`--effort`。

运行环境：Windows、Git Bash、已登录的 Codex CLI。

## 何时走桥

- 有明确产物和可判定完成标准的活交桥，不限大小。
- 不走桥：写任务书和验收比活本身还费 token 的，自己做；判断和方案设计留在 Claude。
- 互不碰同一文件的任务可以各开一个桥并行。

## 1. 定工作目录

`--sandbox workspace-write` 只能写工作目录及其子目录，读不受限。

- 要改源码，工作目录设在能覆盖源码和记录目录的上级（通常是项目根）；否则 Codex 只能出副本和补丁，还得另派人回写。
- 实在要写到工作目录外的另一处，用 `--add-dir <目录>` 显式加可写目录，不放宽 sandbox。

## 2. 写任务书

写成文件放在本轮记录目录（如 `<记录目录>\任务.md`，项目已有 `briefs\` 就放那里）。Codex 看不到对话，任务书必须自洽：

| 段 | 要求 |
|---|---|
| 身份与规则 | 工作语言；要先读的项目规则文件（如 `AGENTS.md`）；工作目录绝对路径；保密要求 |
| 目标 | 一句话说清要得到什么 |
| 输入 | 要读的文件，写绝对路径或相对工作目录的路径 |
| 步骤 | 可执行动作，每步有可观察结果 |
| 边界 | 只在工作目录内写；列出不得改的文件；批处理脚本正文只用 ASCII，中文路径作参数传入 |
| 交付物 | 文件名、位置、内容要求；记录写哪个目录 |
| 自检 | 跑哪些测试/检查，在最终回复里报告结论、改动清单和未完成项 |

不写“上面那个”“刚才那份”之类指代，一律展开。

## 3. 启动

用 Bash 工具 **`run_in_background: true`** 调脚本，结束时自动通知，不要轮询：

```bash
bash ~/.claude/skills/codex-bridge/scripts/run.sh --cd "<工作目录>" --brief "<任务书.md>" --report "<记录目录>/报告.md" --log "<记录目录>/codex_run.log"
```

- `--report`、`--log` 的相对路径按工作目录解析；不给时默认 `报告.md`、`codex_run.log` 落在工作目录。
- 脚本等价于手工起法：`codex.cmd exec -m gpt-6.1-sol -c 'model_reasoning_effort="xhigh"' --sandbox workspace-write --skip-git-repo-check -o 报告.md - < 任务.md > codex_run.log 2>&1`。任务书走标准输入，避开命令行引号和长度限制；选项全放在子命令前。
- 续谈同一会话（多轮返工、被中断后续跑）：加 `--resume <会话id>`，工作目录与原会话一致。相互独立的任务不续接。
- 结束输出给出退出码、会话 id、用量、报告是否生成和日志末尾。
- 脚本先做沙箱预检：Codex 每次开工都以非提权身份给工作目录和 `--add-dir` 加一条沙箱权限，这需要对目录有改权限资格（WRITE_DAC）。属主是 `BUILTIN\Administrators`（提权进程建的、提权 robocopy 迁过来的）或 `CodexSandboxOffline`（Codex 沙箱里建的）的目录，当前用户的普通令牌没有这个资格，Codex 里所有命令都会报 `setup refresh had errors`。根治是用管理员权限一次性给数据根目录授当前用户可继承的 `(RC,WDAC)`（预检会打出命令；只授本人，严禁授给组，否则沙箱用户能改自己的权限）。预检不通过就不启动；跑完若日志含 `setup refresh had errors`，脚本会标明本次结果无效。不改 sandbox、不换目录绕开。

## 4. 跟进度

需要看中途进度时（不是轮询，用户问起或排查卡死时）：

```bash
bash ~/.claude/skills/codex-bridge/scripts/status.sh "<codex_run.log>"
```

日志末尾出现 `tokens used` 就是跑完了。日志长时间不增长、最后修改时间不动才算卡住。

## 5. 中止

只杀自己起的那个 Codex：按命令行里本次唯一的报告路径匹配，用户自己开的 Codex 别碰。

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'codex' -and $_.CommandLine -match [regex]::Escape('<报告文件名或记录目录>') } | Select-Object ProcessId,CommandLine
```

核对清单后再对这些 PID 用 `Stop-Process`；跑偏就停，改任务书重起，不等它跑完。

## 6. 验收

以产物为准，不采信 Codex 自述：

- 交付物存在、内容符合任务书；自检结论与实际测试结果一致（必要时自己重跑关键测试）；
- 没有任务书以外的改动（对比改动前后的文件清单或 diff）；
- 不符就判未通过，写返工任务书（可 `--resume` 同一会话），不在验收时自己补救。

向用户简要回报：做成了什么、用量、产物路径、是否通过验收、返工和中止情况如实说。
