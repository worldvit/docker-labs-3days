#!/usr/bin/env bash
# Day 1 심화(보너스) 채점 — 재시작 정책 · 변경 추적 · 이미지 레이어
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day1-bonus" "Day 1 심화 — 재시작 정책 · 변경 추적 · 이미지 레이어"

restart_policy() {
  [ "$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$1" 2>/dev/null)" = "$2" ]
}

# ---- B1. 재시작 정책 --------------------------------------------------------
check 5  "bonus-always 컨테이너 실행 중"            "태스크 B1" \
      c_running bonus-always

check 5  "bonus-always 의 재시작 정책이 unless-stopped" "태스크 B1" \
      restart_policy bonus-always unless-stopped

# ---- B2. 변경 추적 ----------------------------------------------------------
check 5  "~/result/diff-report.txt 작성 (5줄 이상)"  "태스크 B2" \
      file_lines_min "${HOME}/result/diff-report.txt" 5

check 5  "diff 기록에 변경 유형(A/C/D) 표기 포함"     "태스크 B2" \
      grep -qE '^[ACD] /' "${HOME}/result/diff-report.txt"

# ---- B3. 이미지 레이어 ------------------------------------------------------
check 5  "~/result/layers.txt 작성 (3줄 이상)"       "태스크 B3" \
      file_lines_min "${HOME}/result/layers.txt" 3

check 5  "레이어 수를 숫자로 기록"                    "태스크 B3" \
      grep -qE '[0-9]+' "${HOME}/result/layers.txt"

lab_finish
