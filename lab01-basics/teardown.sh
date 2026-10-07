#!/usr/bin/env bash
# 추가 실습 1-A 정리
set -uo pipefail
echo "추가 실습 1-A 리소스를 삭제합니다. 계속하려면 delete 를 입력하세요."
read -r ANS
[ "$ANS" = "delete" ] || { echo "취소했습니다."; exit 0; }
docker rm -f iso-a iso-hostpid iso-web >/dev/null 2>&1 \
  && echo "[v] 컨테이너 삭제: iso-a, iso-hostpid, iso-web"
echo "[i] 이미지 alpine, nginx:alpine 은 이후 실습에서 다시 쓰므로 남겨 둡니다."
echo "[i] 기록 파일 ~/result/ns-table.txt, isolation.txt 도 남겨 둡니다."
echo "[v] 추가 실습 1-A teardown 완료"
