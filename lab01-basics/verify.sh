#!/usr/bin/env bash
# 추가 실습 1-A 채점 — namespace 격리 확인
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day1-ex-a" "추가 실습 1-A — namespace 격리 확인"

# ---- 로컬 판정 헬퍼 ---------------------------------------------------------
# 컨테이너의 호스트 기준 PID
c_pid() {
  docker inspect -f '{{.State.Pid}}' "$1" 2>/dev/null
}

# namespace inode 번호 (예: pid:[4026532201] → 4026532201)
#   /proc/1/ns 는 root 만 읽을 수 있으므로 sudo -n 으로 읽는다.
ns_inode() {
  sudo -n readlink "/proc/$1/ns/$2" 2>/dev/null | grep -o '[0-9]\+'
}

# 컨테이너의 namespace 가 호스트(PID 1)와 다른가
ns_differs() {
  local p h c
  p="$(c_pid "$1")"; [ -n "$p" ] && [ "$p" != "0" ] || return 1
  h="$(ns_inode 1 "$2")"; c="$(ns_inode "$p" "$2")"
  [ -n "$h" ] && [ -n "$c" ] && [ "$h" != "$c" ]
}

# 컨테이너의 namespace 가 호스트(PID 1)와 같은가
ns_same() {
  local p h c
  p="$(c_pid "$1")"; [ -n "$p" ] && [ "$p" != "0" ] || return 1
  h="$(ns_inode 1 "$2")"; c="$(ns_inode "$p" "$2")"
  [ -n "$h" ] && [ -n "$c" ] && [ "$h" = "$c" ]
}

# 기록 파일에 iso-a 의 실제 호스트 PID 가 적혀 있는가
#   (컨테이너를 다시 만들면 PID 가 바뀌므로, 지금 떠 있는 iso-a 기준)
pid_recorded() {
  local p f="${HOME}/result/isolation.txt"
  p="$(c_pid iso-a)"; [ -n "$p" ] && [ "$p" != "0" ] || return 1
  [ -f "$f" ] && grep -qw "$p" "$f" && ! grep -q '<.*>' "$f"
}

NS_TABLE="${HOME}/result/ns-table.txt"
ISO_TXT="${HOME}/result/isolation.txt"

# ---- 사전 조건 -------------------------------------------------------------
check 5  "Docker 데몬 동작"                          "태스크 1" \
      docker info

# ---- ① 두 시점에서 본 프로세스 ------------------------------------------------
check 10 "iso-a 컨테이너 실행 중"                     "태스크 2" \
      c_running iso-a

# ---- ② namespace 비교표 ----------------------------------------------------
check 10 "iso-a 의 PID namespace 가 호스트와 다름"      "태스크 3" \
      ns_differs iso-a pid

check 5  "iso-a 의 user namespace 가 호스트와 같음"     "태스크 3" \
      ns_same iso-a user

check 10 "~/result/ns-table.txt 작성 (8종 이상)"       "태스크 3" \
      file_lines_min "$NS_TABLE" 9

check 5  "비교표에 같음·다름 판정이 모두 있음"            "태스크 3" \
      bash -c "grep -q '같음' '$NS_TABLE' && grep -q '다름' '$NS_TABLE'"

# ---- ③ 격리 해제 비교 -------------------------------------------------------
check 10 "iso-hostpid 컨테이너 실행 중"               "태스크 4" \
      c_running iso-hostpid

check 10 "iso-hostpid 가 --pid=host 로 실행됨"         "태스크 4" \
      bash -c "[ \"\$(docker inspect -f '{{.HostConfig.PidMode}}' iso-hostpid 2>/dev/null)\" = host ]"

check 5  "iso-hostpid 가 호스트 PID namespace 공유"     "태스크 4" \
      ns_same iso-hostpid pid

# ---- ④ nsenter 진입 대상 ----------------------------------------------------
check 10 "iso-web 컨테이너 실행 중"                   "태스크 5" \
      c_running iso-web

# ---- ⑤ 관찰 기록 ------------------------------------------------------------
check 5  "~/result/isolation.txt 작성 (5줄 이상)"      "태스크 6" \
      file_lines_min "$ISO_TXT" 5

check 10 "기록에 iso-a 의 실제 호스트 PID 기재"          "태스크 6" \
      pid_recorded

check 5  "기록에 nsenter 관찰 내용 포함"               "태스크 6" \
      grep -qi "nsenter" "$ISO_TXT"

lab_finish
