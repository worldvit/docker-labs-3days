#!/usr/bin/env bash
# 채점 결과를 S3에 제출한다.
# 사용법: bash bin/submit.sh day1
set -uo pipefail

BUCKET="${SUBMIT_BUCKET:-docker-edu-submit}"
REGION="${AWS_REGION:-ap-northeast-2}"
RESULT_DIR="${HOME}/result"
ID_FILE="${HOME}/.student_id"

LAB="${1:-}"
if [ -z "$LAB" ]; then
  echo "[오류] 사용법: bash bin/submit.sh <day1|day2|day3>"
  exit 1
fi

if [ ! -f "$ID_FILE" ]; then
  echo "[오류] ~/.student_id 가 없습니다. echo '본인학번' > ~/.student_id 를 먼저 실행하세요."
  exit 1
fi
STUDENT_ID="$(tr -d '[:space:]' < "$ID_FILE")"

SRC="${RESULT_DIR}/${LAB}_result.json"
if [ ! -f "$SRC" ]; then
  echo "[오류] ${SRC} 가 없습니다. 먼저 채점 스크립트를 실행하세요."
  exit 1
fi

DEST="s3://${BUCKET}/${STUDENT_ID}/${LAB}/"

echo "제출 대상: ${DEST}"
aws s3 cp "$SRC" "$DEST" --region "$REGION" || {
  echo "[오류] 업로드 실패. IAM Role 에 s3:PutObject 권한이 있는지 확인하세요."
  exit 1
}

# Day3 는 모니터링 CSV 도 함께 제출한다.
if [ "$LAB" = "day3" ] && [ -f "${RESULT_DIR}/stats.csv" ]; then
  aws s3 cp "${RESULT_DIR}/stats.csv" "$DEST" --region "$REGION"
fi

echo ""
echo "제출된 파일 목록:"
aws s3 ls "$DEST" --region "$REGION"
echo ""
echo "제출이 완료되었습니다."
