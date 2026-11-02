#!/usr/bin/env bash
# 查看一次 Codex 桥运行的进度。用法: status.sh <codex_run.log 路径> [末尾行数=20]
LOG="$1"; N="${2:-20}"
[ -f "$LOG" ] || { echo "日志不存在: $LOG" >&2; exit 2; }
SID=$(grep -m1 -oE 'session id: [0-9a-f-]+' "$LOG" | cut -d' ' -f3)
echo "会话id: ${SID:-未取到}"
if grep -q '^tokens used' "$LOG"; then
  echo "状态: 已跑完（用量 $(grep -A1 -m1 '^tokens used' "$LOG" | tail -1)）"
else
  echo "状态: 未见 tokens used，仍在跑或异常中断"
fi
echo "日志大小: $(wc -c < "$LOG") 字节，最后修改: $(date -r "$LOG" '+%F %T')"
echo "-- 末尾 $N 行 --"
tail -n "$N" "$LOG"
