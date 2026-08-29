#!/usr/bin/env bash
# Lab 1 채점 — 컨테이너 라이프사이클
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day1" "Lab 1 — 컨테이너 라이프사이클과 이미지화"

# ---- 사전 조건 -------------------------------------------------------------
check 5  "Docker 데몬 동작"                    "태스크 1" \
      docker info

# ---- ① web01 8080 공개 -----------------------------------------------------
check 10 "web01 컨테이너 실행 중"               "태스크 3" \
      c_running web01

check 10 "web01 이 호스트 8080 포트에 매핑"      "태스크 3" \
      c_port web01 80 8080

check 5  "web01 이 HTTP 응답 반환"              "태스크 3" \
      http_has "http://127.0.0.1:8080" "<"

# ---- ② index.html 교체 -----------------------------------------------------
check 15 "web01 페이지에 DOCKER-LAB-DAY1 표식"      "태스크 4" \
      http_has "http://127.0.0.1:8080" "$LAB_MARKER"

# ---- ③ commit 으로 이미지화 후 web02 기동 -----------------------------------
check 10 "mynginx:v1 이미지 존재"               "태스크 5" \
      img_exists "mynginx:v1"

check 5  "mynginx:v1 이 commit 으로 생성됨"      "태스크 5" \
      bash -c 'docker image inspect -f "{{.Comment}}{{.Config.Image}}" mynginx:v1 2>/dev/null | grep -qv "^$"'

check 10 "web02 컨테이너 실행 중"               "태스크 5" \
      c_running web02

check 10 "web02 가 호스트 8081 포트에 매핑"      "태스크 5" \
      c_port web02 80 8081

check 10 "web02 페이지에도 표식이 유지됨"          "태스크 5" \
      http_has "http://127.0.0.1:8081" "$LAB_MARKER"

# ---- ④ exec / attach 차이 기록 ---------------------------------------------
check 5  "~/result/attach-exec.txt 작성 (5줄 이상)" "태스크 6" \
      file_lines_min "${HOME}/result/attach-exec.txt" 5

check 5  "기록에 exec 와 attach 가 모두 언급됨"    "태스크 6" \
      bash -c 'grep -qi "exec" "${HOME}/result/attach-exec.txt" && grep -qi "attach" "${HOME}/result/attach-exec.txt"'

lab_finish
