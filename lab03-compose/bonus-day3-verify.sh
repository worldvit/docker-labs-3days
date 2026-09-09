#!/usr/bin/env bash
# Day 3 심화(보너스) 채점 — DNS 해석 비교 · 로그 제한 · healthcheck
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day3-bonus" "Day 3 심화 — DNS 해석 비교 · 로그 제한 · healthcheck"

log_opt_set() {
  docker inspect -f '{{json .HostConfig.LogConfig.Config}}' "$1" 2>/dev/null \
    | grep -q 'max-size'
}
has_healthcheck() {
  [ "$(docker inspect -f '{{if .Config.Healthcheck}}yes{{end}}' "$1" 2>/dev/null)" = "yes" ]
}
is_healthy() {
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = "healthy" ]
}

# ---- B7. upstream vs resolver ----------------------------------------------
check 5  "~/result/lb-compare.txt 작성 (5줄 이상)"   "태스크 B7" \
      file_lines_min "${HOME}/result/lb-compare.txt" 5

check 5  "기록에 upstream 과 resolver 가 모두 언급"  "태스크 B7" \
      bash -c 'grep -qi upstream "$HOME/result/lb-compare.txt" && grep -qi resolver "$HOME/result/lb-compare.txt"'

# ---- B8. 로그 드라이버 제한 -------------------------------------------------
check 5  "shop-app-1 에 로그 크기 제한 적용"          "태스크 B8" \
      log_opt_set shop-app-1

check 5  "shop-web-1 에 로그 크기 제한 적용"          "태스크 B8" \
      log_opt_set shop-web-1

# ---- B9. web healthcheck ----------------------------------------------------
check 5  "shop-web-1 에 healthcheck 정의"            "태스크 B9" \
      has_healthcheck shop-web-1

check 5  "shop-web-1 상태가 healthy"                 "태스크 B9" \
      is_healthy shop-web-1

lab_finish
