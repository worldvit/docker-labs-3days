#!/usr/bin/env bash
# =============================================================================
# 학생용 계정 셋업 — 본인 AWS 계정에서 딱 한 번만 실행합니다.
#
# 실행 위치: AWS CloudShell  (콘솔 우측 상단 터미널 아이콘)
#            EC2 안이 아닙니다. EC2 는 아직 권한이 없기 때문입니다.
#
# 사용법:
#   bash student-setup.sh
#
# 하는 일:
#   1) 내 계정 확인
#   2) EC2 용 IAM 역할 docker-lab-role 생성 (SSM 접속 + ECR)
#   3) 인스턴스 프로파일 생성
#   4) 이름이 docker-lab 으로 시작하는 인스턴스에 자동 연결
#   5) 비용 예산 알림 설정
# =============================================================================
set -uo pipefail

REGION="${AWS_REGION:-ap-northeast-2}"
ROLE="docker-lab-role"

C_G='\033[0;32m'; C_R='\033[0;31m'; C_Y='\033[0;33m'; C_N='\033[0m'
ok()   { echo -e "  ${C_G}[OK]${C_N}   $*"; }
warn() { echo -e "  ${C_Y}[주의]${C_N} $*"; }
die()  { echo -e "  ${C_R}[오류]${C_N} $*"; exit 1; }

echo ""
echo "=== Docker 3일 과정 · 계정 셋업 ==="

# ---- 1. 나는 누구인가 --------------------------------------------------------
ACCT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
  || die "AWS 자격 증명을 찾지 못했습니다. CloudShell 에서 실행하고 있는지 확인하십시오."
ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)"
if [ -z "$ACCT" ] || [ "$ACCT" = "None" ]; then
  die "계정 ID를 확인하지 못했습니다."
fi

echo ""
echo "  계정 ID : $ACCT"
echo "  사용자  : $ARN"
echo "  리전    : $REGION"
echo ""

case "$ARN" in
  *":root") warn "루트 사용자로 실행 중입니다. 평소에는 kdt25 로 로그인하십시오." ;;
esac

# ---- 2. IAM 역할 -------------------------------------------------------------
cat > /tmp/trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole" }
  ]
}
EOF

if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  ok "역할이 이미 있습니다: $ROLE  (정책만 갱신)"
else
  aws iam create-role --role-name "$ROLE" \
    --assume-role-policy-document file:///tmp/trust.json \
    --description "Docker 3days lab" >/dev/null \
    && ok "역할 생성: $ROLE" || die "역할 생성 실패"
fi

aws iam attach-role-policy --role-name "$ROLE" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore >/dev/null \
  && ok "SSM 접속 권한 연결"

cat > /tmp/lab.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "EcrAuthToken", "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
    { "Sid": "EcrLabRepo", "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository","ecr:DescribeRepositories","ecr:DescribeImages",
        "ecr:ListImages","ecr:BatchCheckLayerAvailability","ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer","ecr:InitiateLayerUpload","ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload","ecr:PutImage","ecr:DeleteRepository","ecr:BatchDeleteImage"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${ACCT}:repository/docker-labs" }
  ]
}
EOF

aws iam put-role-policy --role-name "$ROLE" \
  --policy-name docker-lab-policy --policy-document file:///tmp/lab.json >/dev/null \
  && ok "ECR 권한 연결 (docker-labs 리포지토리 전용)"

# ---- 3. 인스턴스 프로파일 -----------------------------------------------------
aws iam create-instance-profile --instance-profile-name "$ROLE" >/dev/null 2>&1
aws iam add-role-to-instance-profile \
  --instance-profile-name "$ROLE" --role-name "$ROLE" >/dev/null 2>&1
ok "인스턴스 프로파일 준비: $ROLE"

echo "  IAM 반영까지 10초 대기..."
sleep 10

# ---- 4. 실습 인스턴스에 연결 ------------------------------------------
IID="$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=docker-lab*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)"

if [ "$IID" = "None" ] || [ -z "$IID" ]; then
  echo ""
  echo -e "  ${C_G}[정상]${C_N} 실습 인스턴스가 아직 없습니다."
  echo "         EC2 를 아직 만들지 않았다면 이것이 정상입니다."
  echo "         다음 단계에서 인스턴스를 만들 때 [고급 세부 정보] →"
  echo "         [IAM 인스턴스 프로파일] 에 ${ROLE} 을 지정하십시오."
  echo ""
  echo "         이미 만든 인스턴스에 붙이려면 이름을 docker-lab 으로 시작하게"
  echo "         고친 뒤 이 스크립트를 다시 실행하십시오."
else
  ASSOC="$(aws ec2 describe-iam-instance-profile-associations --region "$REGION" \
    --filters "Name=instance-id,Values=${IID}" \
    --query 'IamInstanceProfileAssociations[0].AssociationId' --output text 2>/dev/null)"

  if [ "$ASSOC" != "None" ] && [ -n "$ASSOC" ]; then
    aws ec2 replace-iam-instance-profile-association --region "$REGION" \
      --association-id "$ASSOC" --iam-instance-profile Name="$ROLE" >/dev/null \
      && { ok "인스턴스 ${IID} 의 역할을 ${ROLE} 로 교체"
           warn "생성 후에 바꿨으므로 SSM 접속 전에 인스턴스를 재부팅하십시오."; } \
      || warn "역할 교체 실패 — 콘솔에서 직접 바꾸십시오"
  else
    aws ec2 associate-iam-instance-profile --region "$REGION" \
      --instance-id "$IID" --iam-instance-profile Name="$ROLE" >/dev/null \
      && { ok "인스턴스 ${IID} 에 ${ROLE} 연결"
           warn "생성 후에 붙였으므로 SSM 접속 전에 인스턴스를 재부팅하십시오."; } \
      || warn "역할 연결 실패 — 콘솔에서 직접 연결하십시오"
  fi
fi

# ---- 5. 비용 예산 알림 --------------------------------------------------------
read -r -p "  비용 알림을 받을 이메일 (건너뛰려면 Enter): " EMAIL
if [ -n "$EMAIL" ]; then
  cat > /tmp/budget.json <<EOF
{
  "BudgetName": "docker-lab-budget",
  "BudgetLimit": { "Amount": "30", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
  cat > /tmp/notif.json <<EOF
[
  { "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 50,
      "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "${EMAIL}" } ] },
  { "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 90,
      "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "${EMAIL}" } ] }
]
EOF
  aws budgets create-budget --account-id "$ACCT" \
    --budget file:///tmp/budget.json \
    --notifications-with-subscribers file:///tmp/notif.json >/dev/null 2>&1 \
    && ok "예산 알림 설정: 월 \$30 · 50% 와 90% 에서 메일" \
    || warn "예산 알림 설정 실패 (이미 있거나 권한 부족). 콘솔 → Billing → Budgets 에서 확인하십시오."
else
  warn "예산 알림을 건너뛰었습니다. 인스턴스를 끄는 것을 잊지 마십시오."
fi

rm -f /tmp/trust.json /tmp/lab.json /tmp/budget.json /tmp/notif.json

# ---- 마무리 -------------------------------------------------------------------
echo ""
echo "=== 셋업 완료 ==="
echo ""
echo "  이제 EC2 인스턴스를 만드십시오."
echo ""
echo "  [고급 세부 정보] -> [IAM 인스턴스 프로파일] 에서"
echo "  반드시 아래를 선택하십시오. 생성 후에 붙이면 SSM 접속이"
echo "  바로 되지 않아 재부팅이 필요합니다."
echo ""
echo "      ${ROLE}"
echo ""
echo "  인스턴스 생성 후 SSM 으로 접속해 아래를 실행하십시오."
echo ""
echo "      sudo su - ubuntu"
echo "      free -h | head -2"
echo "      nproc"
echo ""
