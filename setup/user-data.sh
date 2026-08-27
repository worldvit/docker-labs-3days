#!/bin/bash
# =============================================================================
# Docker 3일 과정 실습용 EC2 부트스트랩 (Ubuntu 24.04 / t3.medium)
#
# EC2 인스턴스 시작 시 [고급 세부 정보] → [사용자 데이터]에 이 파일 내용을
# 그대로 붙여넣으십시오. 부팅 후 3~5분이면 준비가 끝납니다.
#
# 완료 확인:  cat /var/log/docker-lab-bootstrap.log
#             tail -1 이 [DONE] 이면 정상
# =============================================================================
set -uo pipefail

LOG=/var/log/docker-lab-bootstrap.log
exec > >(tee -a "$LOG") 2>&1
echo "[START] $(date -Iseconds)"

export DEBIAN_FRONTEND=noninteractive
LAB_USER=ubuntu

# --- 1. 기본 패키지 -----------------------------------------------------------
apt-get update -y
apt-get install -y ca-certificates curl gnupg git jq unzip bridge-utils postgresql-client

# --- 2. Docker CE 저장소 등록 --------------------------------------------------
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# --- 3. 실습 계정 권한 ---------------------------------------------------------
usermod -aG docker "$LAB_USER"

# --- 4. AWS CLI v2 -------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  cd /tmp
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -q awscliv2.zip
  ./aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# 기본 리전 고정 — 학생이 --region 을 빠뜨려도 동작하게 한다
mkdir -p /home/${LAB_USER}/.aws
cat > /home/${LAB_USER}/.aws/config <<'EOF'
[default]
region = ap-northeast-2
output = json
EOF
chown -R ${LAB_USER}:${LAB_USER} /home/${LAB_USER}/.aws

# --- 5. 채점 저장소 사전 clone --------------------------------------------------
sudo -u "$LAB_USER" -H git clone --depth 1 \
  https://github.com/worldvit/docker-labs-3days.git \
  /home/${LAB_USER}/docker-labs-3days || echo "[WARN] clone 실패 — 학생이 직접 clone"

sudo -u "$LAB_USER" -H mkdir -p /home/${LAB_USER}/result

# --- 6. 편의 설정 --------------------------------------------------------------
cat > /home/${LAB_USER}/.bash_aliases <<'EOF'
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias di='docker images'
EOF
chown ${LAB_USER}:${LAB_USER} /home/${LAB_USER}/.bash_aliases

# SSM 접속 시 ssm-user 가 아니라 ubuntu 로 시작하도록 안내 배너
cat > /etc/motd <<'EOF'

  ┌──────────────────────────────────────────────────────────┐
  │  Docker 3일 과정 실습 서버                                │
  │                                                          │
  │  1) 먼저 실습 계정으로 전환하십시오:                       │
  │        sudo su - ubuntu                                  │
  │                                                          │
  │  2) 최초 1회만 학번을 등록하십시오:                        │
  │        echo '본인학번' > ~/.student_id                    │
  │                                                          │
  │  채점:  bash ~/docker-labs-3days/lab01-basics/verify.sh   │
  └──────────────────────────────────────────────────────────┘

EOF

# --- 7. 검증 -------------------------------------------------------------------
echo "--- 검증 ---"
docker version --format 'docker  : Client {{.Client.Version}} / Server {{.Server.Version}}' || echo "[FAIL] docker"
docker compose version --short | sed 's/^/compose : /' || echo "[FAIL] compose"
aws --version 2>&1 | sed 's/^/awscli  : /'
docker info 2>/dev/null | grep -i 'Storage Driver' | sed 's/^ */storage : /'
id "$LAB_USER" | sed 's/^/user    : /'

echo "[DONE] $(date -Iseconds)"
