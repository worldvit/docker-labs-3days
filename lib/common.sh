#!/usr/bin/env bash
# docker-labs-3days 공통 채점 라이브러리
# 사용법: source "$(dirname "$0")/../lib/common.sh"

RESULT_DIR="${HOME}/result"
ID_FILE="${HOME}/.student_id"

C_G='\033[0;32m'; C_R='\033[0;31m'; C_Y='\033[0;33m'; C_B='\033[0;36m'; C_N='\033[0m'

TOTAL=0
EARNED=0
declare -a ROWS=()

lab_init() {
  LAB_ID="$1"; LAB_NAME="$2"
  mkdir -p "$RESULT_DIR"
  if [ ! -f "$ID_FILE" ]; then
    echo -e "${C_R}[오류]${C_N} 학번 파일이 없습니다. 먼저 아래를 실행하세요."
    echo "        echo '본인학번' > ~/.student_id"
    exit 1
  fi
  STUDENT_ID="$(tr -d '[:space:]' < "$ID_FILE")"
  if [ -z "$STUDENT_ID" ]; then
    echo -e "${C_R}[오류]${C_N} ~/.student_id 가 비어 있습니다."
    exit 1
  fi
  echo ""
  echo -e "${C_B}[${LAB_ID}] ${LAB_NAME}${C_N}"
  echo -e "  학번: ${STUDENT_ID}   시각: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  ------------------------------------------------------------"
}

# check <배점> <항목명> <되돌아갈 태스크> <판정 명령...>
check() {
  local pts="$1"; local name="$2"; local hint="$3"; shift 3
  TOTAL=$(( TOTAL + pts ))
  if "$@" >/dev/null 2>&1; then
    EARNED=$(( EARNED + pts ))
    printf "  ${C_G}PASS${C_N}  %s  (%d/%d)\n" "$name" "$pts" "$pts"
    ROWS+=("{\"item\":\"${name}\",\"result\":\"PASS\",\"points\":${pts},\"max\":${pts},\"hint\":\"${hint}\"}")
  else
    printf "  ${C_R}FAIL${C_N}  %s  (0/%d)  → %s\n" "$name" "$pts" "$hint"
    ROWS+=("{\"item\":\"${name}\",\"result\":\"FAIL\",\"points\":0,\"max\":${pts},\"hint\":\"${hint}\"}")
  fi
}

lab_finish() {
  local pct=0
  [ "$TOTAL" -gt 0 ] && pct=$(( EARNED * 100 / TOTAL ))
  echo "  ------------------------------------------------------------"
  if [ "$pct" -eq 100 ]; then
    echo -e "  결과: ${C_G}${EARNED}/${TOTAL}점 (${pct}%)  전 항목 통과${C_N}"
  elif [ "$pct" -ge 60 ]; then
    echo -e "  결과: ${C_Y}${EARNED}/${TOTAL}점 (${pct}%)${C_N}  FAIL 항목의 태스크로 돌아가 다시 수행하세요."
  else
    echo -e "  결과: ${C_R}${EARNED}/${TOTAL}점 (${pct}%)${C_N}  FAIL 항목의 태스크로 돌아가 다시 수행하세요."
  fi

  local out="${RESULT_DIR}/${LAB_ID}_result.json"
  {
    printf '{\n'
    printf '  "lab": "%s",\n' "$LAB_ID"
    printf '  "lab_name": "%s",\n' "$LAB_NAME"
    printf '  "student_id": "%s",\n' "$STUDENT_ID"
    printf '  "hostname": "%s",\n' "$(hostname)"
    printf '  "checked_at": "%s",\n' "$(date -Iseconds)"
    printf '  "earned": %d,\n' "$EARNED"
    printf '  "total": %d,\n' "$TOTAL"
    printf '  "percent": %d,\n' "$pct"
    printf '  "details": [\n'
    local i
    for i in "${!ROWS[@]}"; do
      printf '    %s' "${ROWS[$i]}"
      [ "$i" -lt $(( ${#ROWS[@]} - 1 )) ] && printf ','
      printf '\n'
    done
    printf '  ]\n'
    printf '}\n'
  } > "$out"

  echo ""
  echo "  결과 파일: ${out}"
  echo "  제출 명령: bash ~/docker-labs-3days/bin/submit.sh ${LAB_ID}"
  echo ""
}

# ---- 판정 헬퍼 -------------------------------------------------------------

# 컨테이너가 running 상태인가
c_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}

# 컨테이너의 컨테이너포트가 지정 호스트포트로 매핑됐는가
c_port() {
  docker port "$1" "$2" 2>/dev/null | grep -q ":$3\$"
}

# HTTP 응답 본문에 문자열이 포함되는가
http_has() {
  curl -s --max-time 5 "$1" 2>/dev/null | grep -q "$2"
}

# 이미지가 존재하는가
img_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}

# 이미지 크기가 지정 MB 이하인가
img_under_mb() {
  local bytes
  bytes="$(docker image inspect -f '{{.Size}}' "$1" 2>/dev/null)" || return 1
  [ "$bytes" -le $(( $2 * 1024 * 1024 )) ]
}

# 파일이 존재하고 최소 줄 수 이상인가
file_lines_min() {
  [ -f "$1" ] && [ "$(wc -l < "$1")" -ge "$2" ]
}
