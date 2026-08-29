#!/usr/bin/env bash
# Lab 3 정리
set -uo pipefail
echo "Lab 3 리소스를 삭제합니다. 계속하려면 delete 를 입력하세요."
read -r ANS
[ "$ANS" = "delete" ] || { echo "취소했습니다."; exit 0; }
cd "${HOME}/lab03" 2>/dev/null && docker compose down -v && echo "[v] Compose 스택 및 볼륨 삭제"
docker system prune -af --volumes >/dev/null && echo "[v] 전체 미사용 리소스 정리"
echo "[v] Lab 3 teardown 완료"
echo "[!] EC2 인스턴스는 콘솔에서 직접 종료(Terminate)하세요."
