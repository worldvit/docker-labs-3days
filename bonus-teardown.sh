#!/usr/bin/env bash
# 심화(보너스) 실습에서 만든 리소스 정리
set -uo pipefail
echo "심화 실습 리소스를 삭제합니다. 계속하려면 delete 를 입력하세요."
read -r ANS
[ "$ANS" = "delete" ] || { echo "취소했습니다."; exit 0; }
docker rm -f bonus-always bonus-onfail bonus-no bonus-restore 2>/dev/null && echo "[v] 컨테이너 삭제"
docker volume rm -f pgdata-restore 2>/dev/null && echo "[v] 볼륨 삭제: pgdata-restore"
rm -f "${HOME}/lab02/pgdata-backup.tar.gz" 2>/dev/null && echo "[v] 백업 파일 삭제"
echo "[v] 심화 실습 teardown 완료"
