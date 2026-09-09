#!/usr/bin/env bash
# Day 2 심화(보너스) 채점 — 빌드 컨텍스트 · 볼륨 백업 · ECR 스캔
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day2-bonus" "Day 2 심화 — 빌드 컨텍스트 · 볼륨 백업 · ECR 스캔"

vol_exists() { docker volume inspect "$1" >/dev/null 2>&1; }
file_min_kb() { [ -f "$1" ] && [ "$(stat -c%s "$1")" -ge $(( $2 * 1024 )) ]; }

# ---- B4. .dockerignore 효과 -------------------------------------------------
check 5  "~/lab02/app/.dockerignore 존재"            "태스크 B4" \
      test -f "${HOME}/lab02/app/.dockerignore"

check 5  "~/result/context-size.txt 작성 (2줄 이상)" "태스크 B4" \
      file_lines_min "${HOME}/result/context-size.txt" 2

# ---- B5. 볼륨 백업과 복원 ---------------------------------------------------
check 5  "볼륨 백업 파일 생성 (10KB 이상)"           "태스크 B5" \
      file_min_kb "${HOME}/lab02/pgdata-backup.tar.gz" 10

check 5  "복원 볼륨 pgdata-restore 존재"             "태스크 B5" \
      vol_exists pgdata-restore

# ---- B6. ECR 이미지 스캔 ----------------------------------------------------
check 5  "~/result/scan-summary.txt 작성 (3줄 이상)" "태스크 B6" \
      file_lines_min "${HOME}/result/scan-summary.txt" 3

check 5  "스캔 결과에 심각도 표기 포함"               "태스크 B6" \
      grep -qiE 'critical|high|medium|low|findings' "${HOME}/result/scan-summary.txt"

lab_finish
