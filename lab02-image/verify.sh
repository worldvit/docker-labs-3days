#!/usr/bin/env bash
# Lab 2 채점 — 네트워크 · 볼륨 · 이미지 빌드 · ECR
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day2" "Lab 2 — 네트워크 · 볼륨 · 이미지 빌드와 ECR 배포"

# ---- ① 사용자 정의 네트워크 -------------------------------------------------
check 8  "app-net 네트워크 존재"                  "태스크 1" \
      docker network inspect app-net

check 8  "app-net 서브넷이 172.20.0.0/24"          "태스크 1" \
      bash -c 'docker network inspect -f "{{range .IPAM.Config}}{{.Subnet}}{{end}}" app-net 2>/dev/null | grep -q "172.20.0.0/24"'

check 9  "app-net 이 bridge 드라이버 사용"          "태스크 1" \
      bash -c '[ "$(docker network inspect -f "{{.Driver}}" app-net 2>/dev/null)" = "bridge" ]'

# ---- ② 볼륨과 데이터 영속성 -------------------------------------------------
check 8  "pgdata 볼륨 존재"                        "태스크 2" \
      docker volume inspect pgdata

check 8  "labdb 컨테이너 실행 중"                   "태스크 2" \
      c_running labdb

check 9  "labdb 가 pgdata 볼륨을 마운트"            "태스크 2" \
      bash -c 'docker inspect -f "{{range .Mounts}}{{.Name}} {{end}}" labdb 2>/dev/null | grep -qw pgdata'

check 8  "컨테이너 재생성 후 students 데이터 보존"    "태스크 3" \
      bash -c 'docker exec labdb psql -U lab -d labdb -tAc "SELECT count(*) FROM students" 2>/dev/null | grep -qE "^[1-9][0-9]*$"'

# ---- ③ 멀티스테이지 이미지 빌드 ---------------------------------------------
check 8  "myflask:v1 이미지 존재"                   "태스크 4" \
      img_exists "myflask:v1"

check 9  "myflask:v1 이미지 크기 200MB 이하"         "태스크 4" \
      img_under_mb "myflask:v1" 200

check 8  "Dockerfile 이 멀티스테이지 (FROM 2회 이상)" "태스크 4" \
      bash -c '[ "$(grep -ci "^[[:space:]]*FROM " "${HOME}/lab02/app/Dockerfile" 2>/dev/null)" -ge 2 ]'

# ---- ④ ECR 배포 -------------------------------------------------------------
check 8  "ECR 리포지토리 docker-labs 존재"           "태스크 5" \
      bash -c 'aws ecr describe-repositories --repository-names docker-labs --region ap-northeast-2 >/dev/null 2>&1'

check 9  "ECR 에 v1 태그 이미지 push 완료"           "태스크 5" \
      bash -c 'aws ecr describe-images --repository-name docker-labs --image-ids imageTag=v1 --region ap-northeast-2 >/dev/null 2>&1'

lab_finish
