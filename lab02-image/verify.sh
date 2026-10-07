#!/usr/bin/env bash
# Lab 2 채점 — 네트워크 · 볼륨 · 이미지 빌드 · 백업/복원 · ECR
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

lab_init "day2" "Lab 2 — 네트워크 · 볼륨 · 이미지 빌드와 배포"

# ---- 로컬 판정 헬퍼 ---------------------------------------------------------
# tar 아카이브가 비어 있지 않은 정상 파일인가
tar_ok() {
  [ -s "$1" ] && tar -tf "$1" >/dev/null 2>&1
}

# 저장된 아카이브 안에 해당 이미지 태그 정보가 들어 있는가
#
#   Docker 28 의 containerd 이미지 스토어는 docker save 결과를
#   OCI 레이아웃(index.json)으로 내보내고, 기존 스토어는 manifest.json 을 쓴다.
#   둘 다 확인해 저장 방식과 무관하게 동작하게 한다.
tar_has_image() {
  local f="$1" name="$2" members
  [ -s "$f" ] || return 1
  members="$(tar -tf "$f" 2>/dev/null | grep -E '(^|/)(index|manifest)\.json$')"
  if [ -n "$members" ]; then
    # shellcheck disable=SC2086
    tar -xOf "$f" $members 2>/dev/null | grep -q "$name" && return 0
  fi
  # 멤버 이름이 다른 경우 — 아카이브 전체에서 찾는다 (save 결과는 비압축 tar)
  grep -aq "$name" "$f" 2>/dev/null
}

# ---- ① 사용자 정의 네트워크 -------------------------------------------------
check 7  "app-net 네트워크 존재"                  "태스크 1" \
      docker network inspect app-net

check 7  "app-net 서브넷이 172.20.0.0/24"          "태스크 1" \
      bash -c 'docker network inspect -f "{{range .IPAM.Config}}{{.Subnet}}{{end}}" app-net 2>/dev/null | grep -q "172.20.0.0/24"'

check 8  "app-net 이 bridge 드라이버 사용"          "태스크 1" \
      bash -c '[ "$(docker network inspect -f "{{.Driver}}" app-net 2>/dev/null)" = "bridge" ]'

# ---- ② 볼륨과 데이터 영속성 -------------------------------------------------
check 7  "pgdata 볼륨 존재"                        "태스크 2" \
      docker volume inspect pgdata

check 7  "labdb 컨테이너 실행 중"                   "태스크 2" \
      c_running labdb

check 8  "labdb 가 pgdata 볼륨을 마운트"            "태스크 2" \
      bash -c 'docker inspect -f "{{range .Mounts}}{{.Name}} {{end}}" labdb 2>/dev/null | grep -qw pgdata'

check 7  "컨테이너 재생성 후 students 데이터 보존"    "태스크 3" \
      bash -c 'docker exec labdb psql -U lab -d labdb -tAc "SELECT count(*) FROM students" 2>/dev/null | grep -qE "^[1-9][0-9]*$"'

# ---- ③ 멀티스테이지 이미지 빌드 ---------------------------------------------
check 7  "myflask:v1 이미지 존재"                   "태스크 4" \
      img_exists "myflask:v1"

check 8  "myflask:v1 이미지 크기 200MB 이하"         "태스크 4" \
      img_under_mb "myflask:v1" 200

check 7  "Dockerfile 이 멀티스테이지 (FROM 2회 이상)" "태스크 4" \
      bash -c '[ "$(grep -ci "^[[:space:]]*FROM " "${HOME}/lab02/app/Dockerfile" 2>/dev/null)" -ge 2 ]'

# ---- ④ 이미지 백업과 복원 (save / load) -------------------------------------
check 4  "백업 파일 ~/lab02/backup/myflask-v1.tar 존재" "태스크 5" \
      tar_ok "${HOME}/lab02/backup/myflask-v1.tar"

check 4  "아카이브에 myflask:v1 정보 포함"            "태스크 5" \
      tar_has_image "${HOME}/lab02/backup/myflask-v1.tar" "myflask"

check 4  "~/result/save-load.txt 기록 (5줄 이상 · save·load 언급)" "태스크 5" \
      bash -c 'f="${HOME}/result/save-load.txt"; [ -f "$f" ] && [ "$(wc -l < "$f")" -ge 5 ] && grep -qi "save" "$f" && grep -qi "load" "$f"'

# ---- ⑤ ECR 배포 -------------------------------------------------------------
check 7  "ECR 리포지토리 docker-labs 존재"           "태스크 6" \
      bash -c 'aws ecr describe-repositories --repository-names docker-labs --region ap-northeast-2 >/dev/null 2>&1'

check 8  "ECR 에 v1 태그 이미지 push 완료"           "태스크 6" \
      bash -c 'aws ecr describe-images --repository-name docker-labs --image-ids imageTag=v1 --region ap-northeast-2 >/dev/null 2>&1'

lab_finish
