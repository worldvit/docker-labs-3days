#!/usr/bin/env bash
# 배포 중 무중단 여부와 버전 비율을 측정한다.
#
#   사용법: bash bin/deploy-probe.sh [측정초] [출력파일명]
#     예:   bash bin/deploy-probe.sh 90 rolling.csv
#
#   0.2초마다 http://127.0.0.1/ 에 요청을 보내고 CSV 한 줄을 남긴다.
#     timestamp,http_code,version
#   version 판정
#     v2   : 응답에 "version: v2" 가 있음  (신버전)
#     v1   : 응답에 "served-by" 만 있음    (구버전)
#     fail : 응답이 없거나 형식이 다름     (순단)
set -uo pipefail

DUR="${1:-60}"
NAME="${2:-deploy.csv}"
URL="${URL:-http://127.0.0.1/}"
OUT="${HOME}/result/${NAME}"
mkdir -p "$(dirname "$OUT")"

echo "timestamp,http_code,version" > "$OUT"
echo "측정 시작 — ${DUR}초 동안 0.2초 간격  →  ${OUT}"

END=$(( $(date +%s) + DUR ))
while [ "$(date +%s)" -lt "$END" ]; do
  TS="$(date '+%H:%M:%S')"
  RESP="$(curl -s --max-time 2 -w '\n%{http_code}' "$URL" 2>/dev/null)"
  CODE="$(printf '%s' "$RESP" | tail -n 1)"
  BODY="$(printf '%s' "$RESP" | sed '$d')"
  [ -z "$CODE" ] && CODE="000"

  if   printf '%s' "$BODY" | grep -q 'version: v2'; then VER="v2"
  elif printf '%s' "$BODY" | grep -q 'served-by';   then VER="v1"
  else                                                   VER="fail"
  fi

  echo "${TS},${CODE},${VER}" >> "$OUT"
  sleep 0.2
done

echo ""
echo "===== 측정 결과 : ${NAME} ====="
awk -F, 'NR>1 {
  t++; v[$3]++; if ($2 != "200") bad++
  if ($3 == "v1") { if (!f1) f1=$1; l1=$1 }
  if ($3 == "v2") { if (!f2) f2=$1; l2=$1 }
}
END {
  if (t == 0) { print "요청이 기록되지 않았습니다."; exit }
  printf "총 요청        : %d\n", t
  printf "v1 (구버전)    : %5d  (%5.1f%%)\n", v["v1"]+0, (v["v1"]+0)*100/t
  printf "v2 (신버전)    : %5d  (%5.1f%%)\n", v["v2"]+0, (v["v2"]+0)*100/t
  printf "순단(200 아님) : %5d  (%5.1f%%)\n", bad+0,     (bad+0)*100/t
  if (f2 != "") printf "v2 첫 응답     : %s\n", f2
  if (l1 != "") printf "v1 마지막 응답 : %s\n", l1
}' "$OUT"
echo "================================"
echo "원본 CSV : ${OUT}"
