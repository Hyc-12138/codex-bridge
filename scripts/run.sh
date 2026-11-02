#!/usr/bin/env bash
# Codex 桥：前台跑一次 codex exec，跑完打印退出码、会话 id、用量和报告位置。
# 由 Claude 用 Bash 的 run_in_background 调起，结束时自动通知，不需轮询。
#
# 用法:
#   run.sh --cd <工作目录> --brief <任务书.md> [--report 报告.md] [--log codex_run.log]
#          [--add-dir <可写目录>]... [--resume <会话id>] [--model gpt-6.1-sol] [--effort xhigh]
# --report/--log 的相对路径按工作目录解析；--brief 的相对路径按调用时当前目录解析。

CODEX="${CODEX_BRIDGE_BIN:-$(command -v codex.cmd || command -v codex)}"
MODEL="gpt-6.1-sol"
EFFORT="xhigh"
REPORT="报告.md"
LOG="codex_run.log"
WORKDIR=""
BRIEF=""
RESUME=""
ADD_DIRS=()
CHECK_DIRS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --cd) WORKDIR="$2"; shift 2 ;;
    --brief) BRIEF="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --add-dir) ADD_DIRS+=(--add-dir "$2"); CHECK_DIRS+=("$2"); shift 2 ;;
    --resume) RESUME="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

[ -n "$WORKDIR" ] && [ -n "$BRIEF" ] || { echo "必须给 --cd 和 --brief" >&2; exit 2; }
[ -d "$WORKDIR" ] || { echo "工作目录不存在: $WORKDIR" >&2; exit 2; }
[ -f "$BRIEF" ] || { echo "任务书不存在: $BRIEF" >&2; exit 2; }
[ -n "$CODEX" ] && [ -f "$CODEX" ] || { echo "找不到 Codex CLI，放进 PATH 或设 CODEX_BRIDGE_BIN: $CODEX" >&2; exit 2; }

BRIEF_ABS="$(cd "$(dirname "$BRIEF")" && pwd)/$(basename "$BRIEF")"
cd "$WORKDIR" || exit 2

# 沙箱启动前检查：可写根的属主不是本用户且无沙箱权限时，Codex 命令全部起不来，直接停。
CB_PATHS="$(cygpath -w "$(pwd)")"
for d in "${CHECK_DIRS[@]}"; do CB_PATHS="$CB_PATHS|$(cygpath -w "$d")"; done
export CB_PATHS
PRE="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$(dirname "$0")/preflight.ps1")")"
PRE_RC=$?
if [ $PRE_RC -ne 0 ]; then
  echo "== Codex 桥未启动：沙箱预检不通过 =="
  echo "$PRE"
  exit $PRE_RC
fi

# 选项全放在 resume 子命令前；任务书走标准输入，避开 cmd 的引号和 8191 字符限制。
ARGS=(exec -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" --sandbox workspace-write
      --skip-git-repo-check "${ADD_DIRS[@]}" -o "$REPORT")
if [ -n "$RESUME" ]; then
  ARGS+=(resume "$RESUME" -)
else
  ARGS+=(-)
fi

START=$(date '+%F %T')
"$CODEX" "${ARGS[@]}" < "$BRIEF_ABS" > "$LOG" 2>&1
RC=$?
END=$(date '+%F %T')

SID=$(grep -m1 -oE 'session id: [0-9a-f-]+' "$LOG" | cut -d' ' -f3)
TOKENS=$(grep -A1 -m1 '^tokens used' "$LOG" | tail -1)

echo "== Codex 桥结束 =="
if grep -q "setup refresh had errors" "$LOG"; then
  echo "!! 沙箱初始化失败（setup refresh had errors）：本次结果无效，Codex 里的命令都没跑起来。按 preflight 的根治命令处理后原样重跑。"
fi
echo "工作目录: $(pwd)"
echo "起止: $START → $END"
echo "退出码: $RC"
echo "会话id: ${SID:-未取到}"
echo "用量: ${TOKENS:-日志无 tokens used，未正常跑完}"
abs() { case "$1" in /*|[A-Za-z]:*) echo "$1";; *) echo "$(pwd)/$1";; esac; }
echo "报告: $(abs "$REPORT") $( [ -s "$REPORT" ] && echo '(已生成)' || echo '(缺失或为空)')"
echo "日志: $(abs "$LOG")"
echo "-- 日志末尾 --"
tail -n 15 "$LOG"
exit $RC
