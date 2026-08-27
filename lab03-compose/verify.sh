#!/usr/bin/env bash
# Lab 3 채점 — Compose 3-Tier · 스케일 아웃 · 리소스 제한 · 모니터링
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day3" "Lab 3 — Compose 3-Tier 종합 구축"

PROJ="${PROJ:-shop}"
FLASK_FILTER="label=com.docker.compose.project=${PROJ}"

# ---- ① 3계층 스택 구성 ------------------------------------------------------
check 8  "Compose 프로젝트 ${PROJ} 기동 중"          "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' | grep -q ."

check 8  "web(Nginx) 서비스 실행 중"                "태스크 3" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=web' | grep -q ."

check 8  "app(Flask) 서비스 실행 중"                "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | grep -q ."

check 9  "db(PostgreSQL) 서비스 실행 중"            "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=db' | grep -q ."

# ---- ② 스케일 아웃과 로드밸런싱 ---------------------------------------------
check 9  "app 컨테이너가 3개로 스케일아웃"            "태스크 4" \
      bash -c "[ \$(docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | wc -l) -eq 3 ]"

check 8  "80 포트로 애플리케이션 응답"               "태스크 3" \
      http_has "http://127.0.0.1/" "."

check 8  "요청이 서로 다른 컨테이너로 분산"           "태스크 4" \
      bash -c 'for i in $(seq 1 12); do curl -s --max-time 3 http://127.0.0.1/; echo; done | sort -u | wc -l | grep -qvE "^(0|1)$"'

# ---- ③ 네트워크 격리 --------------------------------------------------------
check 8  "db 가 호스트 포트를 노출하지 않음"          "태스크 5" \
      bash -c "! docker ps --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=db' --format '{{.Ports}}' | grep -q '0.0.0.0'"

check 9  "app 이 호스트 포트를 직접 노출하지 않음"     "태스크 5" \
      bash -c "! docker ps --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' --format '{{.Ports}}' | grep -q '0.0.0.0'"

# ---- ④ 리소스 제한과 모니터링 ------------------------------------------------
check 8  "app 에 메모리 제한 적용"                   "태스크 6" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | head -1 | xargs -r docker inspect -f '{{.HostConfig.Memory}}' | grep -qvE '^0?\$'"

check 8  "app 에 CPU 제한 적용"                     "태스크 6" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | head -1 | xargs -r docker inspect -f '{{.HostConfig.NanoCpus}}' | grep -qvE '^0?\$'"

check 9  "stats.csv 수집 (헤더 포함 10줄 이상)"       "태스크 7" \
      file_lines_min "${HOME}/result/stats.csv" 10

lab_finish
