# docker-labs-3days

Docker 3일(24시간) 과정의 **자가 채점 스크립트**와 **사전 배포 자료** 저장소입니다.
학생은 이 저장소를 자신의 EC2에 clone 한 뒤, 각 일차 실습을 마치고 스스로 채점하고 결과를 S3에 제출합니다.

## 최초 1회 준비

```bash
cd ~
git clone https://github.com/worldvit/docker-labs-3days.git
echo '본인학번' > ~/.student_id
```

`~/.student_id` 가 없으면 모든 채점 스크립트가 실행을 거부합니다.

## 매일 아침 — 최신본으로 갱신

```bash
cd ~/docker-labs-3days && git pull
```

## 채점과 제출

| 일차 | 채점 | 제출 |
|---|---|---|
| Day 1 | `bash ~/docker-labs-3days/lab01-basics/verify.sh` | `bash ~/docker-labs-3days/bin/submit.sh day1` |
| Day 2 | `bash ~/docker-labs-3days/lab02-image/verify.sh` | `bash ~/docker-labs-3days/bin/submit.sh day2` |
| Day 3 | `bash ~/docker-labs-3days/lab03-compose/verify.sh` | `bash ~/docker-labs-3days/bin/submit.sh day3` |

채점 결과는 `~/result/<lab>_result.json` 으로 저장되고, 제출 시 `s3://docker-edu-submit/<학번>/<lab>/` 에 업로드됩니다.

## 디렉터리 구조

```
docker-labs-3days/
├── lib/common.sh              채점 공통 라이브러리 (PASS/FAIL 판정, JSON 출력)
├── lab01-basics/
│   ├── verify.sh              Day 1 채점 (100점)
│   └── teardown.sh            Day 1 정리
├── lab02-image/
│   ├── verify.sh              Day 2 채점 (100점)
│   └── teardown.sh            Day 2 정리
├── lab03-compose/
│   ├── verify.sh              Day 3 채점 (100점)
│   └── teardown.sh            Day 3 정리
├── bin/
│   ├── submit.sh              결과 JSON S3 업로드
│   └── stats-collect.sh       docker stats 주기 수집 → CSV
├── assets/
│   ├── flask-app/             Day 2·3 실습용 Flask 앱 (app.py, Dockerfile, requirements.txt)
│   └── lab03/                 Day 3 실습용 nginx.conf, init.sql, compose.reference.yaml
└── setup/                     강사 전용 — 학생은 볼 필요 없음
    ├── user-data.sh           EC2 부트스트랩 (Docker 설치 자동화)
    ├── iam-trust-policy.json  EC2 신뢰 정책
    ├── iam-policy-shared.json 반 공용 권한 정책
    ├── iam-policy-per-student.json  학번별 프리픽스 격리 정책
    ├── create-student-roles.sh      학번별 IAM 역할 일괄 생성
    ├── collect-results.sh           S3 제출물 → 성적표 CSV
    └── students.csv                 명단 예시 (학번,이름)
```

## 강사 준비 (개강 전)

```bash
# 1) 제출 버킷 생성 + 버전 관리
aws s3 mb s3://docker-edu-submit --region ap-northeast-2
aws s3api put-bucket-versioning --bucket docker-edu-submit \
  --versioning-configuration Status=Enabled

# 2) 학번별 IAM 역할 생성 (setup/students.csv 를 먼저 채우십시오)
bash setup/create-student-roles.sh setup/students.csv

# 3) EC2 생성 시 사용자 데이터에 setup/user-data.sh 내용을 붙여넣고
#    IAM 인스턴스 프로파일로 docker-lab-role-<학번> 을 지정

# 4) 수업 종료 후 성적 집계
bash setup/collect-results.sh setup/students.csv

# 5) 과정 종료 후 역할 정리
bash setup/create-student-roles.sh setup/students.csv --delete
```

## 채점 항목 요약

**Day 1 (Lab 1) — 컨테이너 라이프사이클**
Docker 데몬 동작 · web01 실행과 8080 매핑 · 학번 표시 · mynginx:v1 이미지 · web02 8081 · exec/attach 기록

**Day 2 (Lab 2) — 네트워크 · 볼륨 · 이미지**
app-net(172.20.0.0/24) · pgdata 볼륨과 데이터 보존 · myflask:v1 200MB 이하 · 멀티스테이지 · ECR push

**Day 3 (Lab 3) — Compose 3-Tier**
web/app/db 3계층 기동 · app 3 replica · 라운드로빈 분산 · db·app 호스트 포트 미노출 · 메모리·CPU 제한 · stats.csv

## 환경 전제

- AWS 서울 리전(`ap-northeast-2`), EC2 `t3.medium`, Ubuntu 24.04 LTS
- 접속은 SSM Session Manager (SSH 키·22번 포트 미사용)
- Docker CE 28.x (containerd 이미지 스토어)
- EC2 인스턴스 프로파일에 `ecr:*`, `s3:PutObject` 권한 필요

## 강사용 참고

`SUBMIT_BUCKET` 환경변수로 제출 버킷을 바꿀 수 있습니다.

```bash
SUBMIT_BUCKET=my-bucket bash bin/submit.sh day1
```

Day 3 채점은 Compose 프로젝트 이름을 `shop` 으로 가정합니다. 다르면 `PROJ` 로 지정하십시오.

```bash
PROJ=myproject bash lab03-compose/verify.sh
```
