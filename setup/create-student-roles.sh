#!/usr/bin/env bash
# =============================================================================
# 학번별 IAM 역할 + 인스턴스 프로파일 생성 (프리픽스 격리)
#
# 사용법:
#   bash setup/create-student-roles.sh setup/students.csv
#   bash setup/create-student-roles.sh setup/students.csv --delete   # 정리
#
# 학생마다 역할을 따로 만들어 S3 제출 경로를 본인 프리픽스로 제한합니다.
# 반 전체가 하나의 역할을 공유해도 되면 iam-policy-shared.json 을 쓰십시오.
# =============================================================================
set -uo pipefail

ROSTER="${1:-setup/students.csv}"
MODE="${2:-create}"
REGION="${AWS_REGION:-ap-northeast-2}"
BUCKET="${SUBMIT_BUCKET:-docker-edu-submit}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$ROSTER" ]; then
  echo "[오류] 명단 파일이 없습니다: $ROSTER"
  echo "       형식: 학번,이름  (헤더 한 줄 포함)"
  exit 1
fi

ACCT="$(aws sts get-caller-identity --query Account --output text)" || exit 1
echo "계정: $ACCT   리전: $REGION   버킷: $BUCKET"
echo ""

while IFS=, read -r SID NAME; do
  SID="$(echo "$SID" | tr -d '[:space:]')"
  [ -z "$SID" ] && continue
  [ "$SID" = "학번" ] && continue          # 헤더 건너뛰기
  case "$SID" in \#*) continue ;; esac      # 주석 건너뛰기

  ROLE="docker-lab-role-${SID}"
  POLICY="docker-lab-policy-${SID}"

  if [ "$MODE" = "--delete" ]; then
    echo "[삭제] $ROLE"
    aws iam remove-role-from-instance-profile --instance-profile-name "$ROLE" --role-name "$ROLE" 2>/dev/null
    aws iam delete-instance-profile --instance-profile-name "$ROLE" 2>/dev/null
    aws iam detach-role-policy --role-name "$ROLE" \
      --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null
    aws iam delete-role-policy --role-name "$ROLE" --policy-name "$POLICY" 2>/dev/null
    aws iam delete-role --role-name "$ROLE" 2>/dev/null
    continue
  fi

  echo "[생성] $ROLE  (${NAME:-이름없음})"

  aws iam create-role --role-name "$ROLE" \
    --assume-role-policy-document "file://${HERE}/iam-trust-policy.json" \
    --description "Docker 3days lab - ${SID}" >/dev/null 2>&1 \
    || echo "       역할이 이미 있습니다 — 정책만 갱신합니다"

  # SSM 접속 권한은 AWS 관리형 정책을 붙인다
  aws iam attach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore >/dev/null

  # ECR + 본인 프리픽스 전용 S3 권한
  sed -e "s/ACCOUNT_ID/${ACCT}/g" \
      -e "s/STUDENT_ID/${SID}/g" \
      -e "s/docker-edu-submit/${BUCKET}/g" \
      "${HERE}/iam-policy-per-student.json" > "/tmp/${POLICY}.json"

  aws iam put-role-policy --role-name "$ROLE" \
    --policy-name "$POLICY" \
    --policy-document "file:///tmp/${POLICY}.json" >/dev/null
  rm -f "/tmp/${POLICY}.json"

  # 인스턴스 프로파일 — EC2 에 붙이는 것은 역할이 아니라 이 이름입니다
  aws iam create-instance-profile --instance-profile-name "$ROLE" >/dev/null 2>&1
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$ROLE" --role-name "$ROLE" >/dev/null 2>&1

  echo "       인스턴스 프로파일: $ROLE"
done < "$ROSTER"

echo ""
if [ "$MODE" = "--delete" ]; then
  echo "삭제가 완료되었습니다."
else
  echo "생성이 완료되었습니다."
  echo "EC2 생성 시 [고급 세부 정보] → [IAM 인스턴스 프로파일]에"
  echo "학생별 docker-lab-role-<학번> 을 지정하십시오."
fi
