#!/usr/bin/env bash
# Lab 2 정리
set -uo pipefail
echo "Lab 2 리소스를 삭제합니다. 계속하려면 delete 를 입력하세요."
read -r ANS
[ "$ANS" = "delete" ] || { echo "취소했습니다."; exit 0; }
docker rm -f labdb labapp 2>/dev/null && echo "[v] 컨테이너 삭제"
docker volume rm -f pgdata 2>/dev/null && echo "[v] 볼륨 삭제: pgdata"
docker network rm app-net 2>/dev/null && echo "[v] 네트워크 삭제: app-net"
docker rmi -f myflask:v1 2>/dev/null && echo "[v] 이미지 삭제: myflask:v1"
echo "[!] ECR 리포지토리는 과금 대상입니다. 필요 없으면 아래를 실행하세요."
echo "    aws ecr delete-repository --repository-name docker-labs --force --region ap-northeast-2"
echo "[v] Lab 2 teardown 완료"
