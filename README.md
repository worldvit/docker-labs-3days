# docker-labs-3days

Docker 3일(24시간) 과정의 **자가 채점 스크립트**와 **사전 배포 자료** 저장소입니다.
학생은 이 저장소를 자신의 EC2에 clone 한 뒤, 각 일차 실습을 마치고 스스로 채점합니다.

## 실습 계정 구조

이 과정은 **학생마다 독립된 AWS 계정**을 씁니다. 각자 `kdt25` IAM 사용자로 AdministratorAccess 를 가지므로 **환경 준비를 본인이 직접** 합니다.

```
[내 AWS 계정]
  kdt25 (Administrator)
     |
     +-- EC2  docker-lab-<이름>
     |     └ IAM 역할 docker-lab-role  (SSM 접속 + ECR)
     |
     +-- ECR  docker-labs             ← Day 2 에서 사용
     |
     +-- 채점 결과는 ~/result/ 에만 저장됩니다.
         제출·업로드 없이 화면 점수를 강사에게 보여주면 끝입니다.
```

**제출 절차가 없습니다.** S3 버킷도, 학번 등록도 필요하지 않습니다.

## 최초 1회 준비

### 1. CloudShell 에서 계정 셋업

```bash
curl -O https://raw.githubusercontent.com/worldvit/docker-labs-3days/main/setup/student-setup.sh
bash student-setup.sh
```

IAM 역할 `docker-lab-role` 생성 → 인스턴스 프로파일 연결 → 비용 예산 알림까지 한 번에 처리합니다.
EC2 는 **이름을 `docker-lab` 으로 시작**하게 만들어야 스크립트가 찾아서 역할을 붙입니다.

### 2. EC2 생성

사용자 데이터에 `setup/user-data.sh` 내용을 붙여넣으면 Docker CE 28 과 AWS CLI 가 자동 설치됩니다.

### 3. EC2 안에서

```bash
sudo su - ubuntu
cd ~/docker-labs-3days && git pull
docker version
```

## 채점

| 일차 | 채점 명령 |
|---|---|
| Day 1 | `bash ~/docker-labs-3days/lab01-basics/verify.sh` |
| Day 2 | `bash ~/docker-labs-3days/lab02-image/verify.sh` |
| Day 3 | `bash ~/docker-labs-3days/lab03-compose/verify.sh` |

각 100점이며 **횟수 제한 없이 다시 실행**할 수 있습니다. `FAIL` 옆에 돌아갈 태스크 번호가 표시됩니다.
100점이 되면 화면을 강사에게 보여주고 그 교시를 마칩니다. 결과 JSON 은 `~/result/<lab>_result.json` 에 남습니다.

## 디렉터리 구조

```
docker-labs-3days/
├── lib/common.sh              채점 공통 라이브러리 (PASS/FAIL 판정, JSON 출력)
├── lab01-basics/
│   ├── verify.sh              Day 1 채점 (100점)
│   └── teardown.sh            Day 1 정리
├── lab02-image/               Day 2 채점 · 정리
├── lab03-compose/             Day 3 채점 · 정리
├── bin/
│   └── stats-collect.sh       docker stats 주기 수집 → CSV
├── assets/
│   ├── flask-app/             Day 2·3 실습용 Flask 앱
│   └── lab03/                 Day 3 실습용 nginx.conf, init.sql, compose 참고본
└── setup/
    ├── student-setup.sh       계정 셋업 — CloudShell 에서 1회
    └── user-data.sh           EC2 부트스트랩 (사용자 데이터에 붙여넣기)
```

## 채점 항목 요약

**Day 1 (Lab 1) — 컨테이너 라이프사이클**
Docker 데몬 · web01 실행과 8080 매핑 · `DOCKER-LAB-DAY1` 표식 · mynginx:v1 이미지 · web02 8081 · exec/attach 기록

**Day 2 (Lab 2) — 네트워크 · 볼륨 · 이미지**
app-net(172.20.0.0/24) · pgdata 볼륨과 데이터 보존 · myflask:v1 200MB 이하 · 멀티스테이지 · ECR push

**Day 3 (Lab 3) — Compose 3-Tier**
web/app/db 3계층 기동 · app 3 replica · 라운드로빈 분산 · db·app 호스트 포트 미노출 · 메모리·CPU 제한 · stats.csv

## 환경 전제

- AWS 서울 리전(`ap-northeast-2`), EC2 `t3.medium`, Ubuntu 24.04 LTS
- 접속은 SSM Session Manager (SSH 키·22번 포트 미사용)
- Docker CE 28.x (containerd 이미지 스토어)
- IAM 역할에 `AmazonSSMManagedInstanceCore` 와 ECR `docker-labs` 권한

## 참고

Day 3 채점은 Compose 프로젝트 이름을 `shop` 으로 가정합니다. 다르면 `PROJ` 로 지정하십시오.

```bash
PROJ=myproject bash lab03-compose/verify.sh
```
