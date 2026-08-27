#!/usr/bin/env bash
# docker stats 를 주기적으로 수집해 CSV로 저장한다.
# 사용법: bash bin/stats-collect.sh [수집횟수] [간격초]
set -uo pipefail

COUNT="${1:-10}"
INTERVAL="${2:-30}"
OUT="${HOME}/result/stats.csv"
mkdir -p "$(dirname "$OUT")"

echo "timestamp,name,cpu_percent,mem_usage,mem_percent,net_io,block_io" > "$OUT"

for i in $(seq 1 "$COUNT"); do
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  docker stats --no-stream \
    --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}' \
  | sed "s|^|${TS},|" | tr -d '%' >> "$OUT"
  echo "[$i/$COUNT] 수집 완료 ($(date '+%H:%M:%S'))"
  [ "$i" -lt "$COUNT" ] && sleep "$INTERVAL"
done

echo ""
echo "저장 위치: $OUT  (총 $(wc -l < "$OUT") 줄)"
