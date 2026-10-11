#!/usr/bin/env bash
# Lab 3 채점 — Compose 3-Tier · 스케일 아웃 · 리소스 제한 · 모니터링 · 무중단 배포
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day3" "Lab 3 — Compose 3-Tier 와 무중단 배포"

PROJ="${PROJ:-shop}"
FLASK_FILTER="label=com.docker.compose.project=${PROJ}"

# ---- 로컬 판정 헬퍼 ---------------------------------------------------------
# deploy-probe.sh 가 남긴 CSV 가 쓸 만한가
#   · 헤더를 뺀 요청 수가 최소치 이상인가
#   · 구버전(v1)과 신버전(v2) 응답이 모두 기록되었는가 — 전환이 실제로 일어났다는 증거
probe_ok() {
  local f="${HOME}/result/$1" min="${2:-50}" n
  [ -f "$f" ] || return 1
  n="$(wc -l < "$f")"
  [ "$(( n - 1 ))" -ge "$min" ] || return 1
  grep -q ',v1$' "$f" && grep -q ',v2$' "$f"
}

# 카나리는 "섞여 있는 상태"가 핵심이다.
# 두 버전이 모두 기록되고, v2 비율이 5~60% 안에 들어야 일부에만 보냈다고 볼 수 있다.
canary_ok() {
  local f="${HOME}/result/canary.csv"
  probe_ok "canary.csv" 50 || return 1
  awk -F, 'NR>1 { t++; if ($3 == "v2") g++ }
           END  { if (t < 50) exit 1
                  r = (g + 0) * 100 / t
                  exit !(r >= 5 && r <= 60) }' "$f"
}

# 비교표가 세 전략을 모두 다루고 있는가
compare_ok() {
  local f="${HOME}/result/deploy-compare.md"
  [ -f "$f" ] || return 1
  [ "$(wc -l < "$f")" -ge 8 ] || return 1
  grep -q '롤링' "$f" && grep -q '블루' "$f" && grep -q '카나리' "$f"
}

# ---- ① 3계층 스택 구성 ------------------------------------------------------
check 6  "Compose 프로젝트 ${PROJ} 기동 중"          "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' | grep -q ."

check 6  "web(Nginx) 서비스 실행 중"                "태스크 3" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=web' | grep -q ."

check 6  "app(Flask) 서비스 실행 중"                "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | grep -q ."

check 6  "db(PostgreSQL) 서비스 실행 중"            "태스크 2" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=db' | grep -q ."

# ---- ② 스케일 아웃과 로드밸런싱 ---------------------------------------------
check 6  "app 컨테이너가 3개로 스케일아웃"            "태스크 4" \
      bash -c "[ \$(docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | wc -l) -eq 3 ]"

check 6  "80 포트로 애플리케이션 응답"               "태스크 3" \
      http_has "http://127.0.0.1/" "."

check 6  "요청이 서로 다른 컨테이너로 분산"           "태스크 4" \
      bash -c 'for i in $(seq 1 12); do curl -s --max-time 3 http://127.0.0.1/; echo; done | sort -u | wc -l | grep -qvE "^(0|1)$"'

# ---- ③ 네트워크 격리 --------------------------------------------------------
check 6  "db 가 호스트 포트를 노출하지 않음"          "태스크 3" \
      bash -c "! docker ps --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=db' --format '{{.Ports}}' | grep -q '0.0.0.0'"

check 6  "app 이 호스트 포트를 직접 노출하지 않음"     "태스크 3" \
      bash -c "! docker ps --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' --format '{{.Ports}}' | grep -q '0.0.0.0'"

# ---- ④ 리소스 제한과 모니터링 ------------------------------------------------
check 5  "app 에 메모리 제한 적용"                   "태스크 5" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | head -1 | xargs -r docker inspect -f '{{.HostConfig.Memory}}' | grep -qvE '^0?\$'"

check 5  "app 에 CPU 제한 적용"                     "태스크 5" \
      bash -c "docker ps -q --filter '${FLASK_FILTER}' --filter 'label=com.docker.compose.service=app' | head -1 | xargs -r docker inspect -f '{{.HostConfig.NanoCpus}}' | grep -qvE '^0?\$'"

check 6  "stats.csv 수집 (헤더 포함 10줄 이상)"       "태스크 6" \
      file_lines_min "${HOME}/result/stats.csv" 10

# ---- ⑤ 무중단 배포 세 전략 ---------------------------------------------------
check 5  "myflask:v2 이미지 존재"                    "태스크 7" \
      img_exists "myflask:v2"

check 7  "rolling.csv 측정 (50요청 이상 · v1·v2 모두 기록)"   "태스크 8" \
      probe_ok "rolling.csv" 50

check 7  "bluegreen.csv 측정 (50요청 이상 · v1·v2 모두 기록)" "태스크 9" \
      probe_ok "bluegreen.csv" 50

check 7  "canary.csv 측정 (v2 비율이 5~60% 구간)"             "태스크 10" \
      canary_ok

check 4  "deploy-compare.md 비교표 작성 (8줄 이상 · 세 전략 언급)" "태스크 11" \
      compare_ok

lab_finish
