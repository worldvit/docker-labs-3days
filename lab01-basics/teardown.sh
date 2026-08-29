#!/usr/bin/env bash
# Lab 1 정리
set -uo pipefail
echo "Lab 1 리소스를 삭제합니다. 계속하려면 delete 를 입력하세요."
read -r ANS
[ "$ANS" = "delete" ] || { echo "취소했습니다."; exit 0; }
docker rm -f web01 web02 2>/dev/null && echo "[v] 컨테이너 삭제: web01, web02"
docker rmi -f mynginx:v1 2>/dev/null && echo "[v] 이미지 삭제: mynginx:v1"
docker system prune -f >/dev/null && echo "[v] 미사용 리소스 정리"
echo "[v] Lab 1 teardown 완료"
