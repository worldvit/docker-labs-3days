#!/usr/bin/env bash
# =============================================================================
# 강사용 성적 집계
#
# S3 에 모인 학생별 채점 JSON 을 내려받아 성적표 CSV 로 만듭니다.
#
# 사용법:
#   bash setup/collect-results.sh                      # 명단 없이, 제출자만 집계
#   bash setup/collect-results.sh setup/students.csv   # 명단 기준, 미제출자도 표시
#
# 산출물:
#   ./grades/  아래에 내려받은 원본 JSON
#   ./grades/성적표_YYYYMMDD.csv
#   ./grades/항목별_오답_YYYYMMDD.csv    (어느 항목에서 많이 틀렸는지)
# =============================================================================
set -uo pipefail

ROSTER="${1:-}"
BUCKET="${SUBMIT_BUCKET:-docker-edu-submit}"
REGION="${AWS_REGION:-ap-northeast-2}"
OUT="./grades"
TODAY="$(date +%Y%m%d)"

mkdir -p "$OUT"

echo "S3 에서 제출물을 내려받습니다: s3://${BUCKET}/"
aws s3 sync "s3://${BUCKET}/" "$OUT/raw/" --exclude "*" --include "*.json" \
  --region "$REGION" --only-show-errors || {
    echo "[오류] 다운로드 실패. 버킷 이름과 권한을 확인하십시오."
    exit 1
}

FOUND=$(find "$OUT/raw" -name '*_result.json' 2>/dev/null | wc -l)
echo "제출 파일 ${FOUND}건을 찾았습니다."
echo ""

python3 - "$OUT" "$TODAY" "$ROSTER" <<'PY'
import csv, json, os, sys, glob
from collections import defaultdict

out_dir, today, roster_path = sys.argv[1], sys.argv[2], sys.argv[3]
raw = os.path.join(out_dir, "raw")

# 학번 -> {day1: {...}, day2: {...}, day3: {...}}
data = defaultdict(dict)
item_fail = defaultdict(lambda: defaultdict(int))   # lab -> item -> 실패 인원

for path in glob.glob(os.path.join(raw, "**", "*_result.json"), recursive=True):
    try:
        with open(path, encoding="utf-8") as f:
            j = json.load(f)
    except Exception as e:
        print(f"[경고] 읽기 실패 {path}: {e}")
        continue

    sid = str(j.get("student_id", "")).strip()
    lab = j.get("lab", "")
    if not sid or lab not in ("day1", "day2", "day3"):
        continue

    prev = data[sid].get(lab)
    # 같은 학생이 여러 번 제출했으면 점수가 높은 쪽을 채택
    if prev is None or j.get("earned", 0) > prev.get("earned", 0):
        data[sid][lab] = j

    for d in j.get("details", []):
        if d.get("result") == "FAIL":
            item_fail[lab][d.get("item", "?")] += 1

# 명단 읽기 (있으면 미제출자도 행으로 남긴다)
names = {}
order = []
if roster_path and os.path.exists(roster_path):
    with open(roster_path, encoding="utf-8-sig") as f:
        for row in csv.reader(f):
            if not row:
                continue
            sid = row[0].strip()
            if not sid or sid.startswith("#") or sid == "학번":
                continue
            names[sid] = row[1].strip() if len(row) > 1 else ""
            order.append(sid)
else:
    order = sorted(data.keys())

# ---- 성적표 -----------------------------------------------------------------
grade_path = os.path.join(out_dir, f"성적표_{today}.csv")
with open(grade_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["학번", "이름", "Day1", "Day2", "Day3", "합계", "백분율", "판정", "최종제출시각"])

    submitted = missing = passed = 0
    total_sum = 0

    for sid in order:
        labs = data.get(sid, {})
        scores = []
        for lab in ("day1", "day2", "day3"):
            j = labs.get(lab)
            scores.append(j["earned"] if j else "")
        got = sum(s for s in scores if isinstance(s, int))
        pct = round(got / 300 * 100, 1)

        times = [j.get("checked_at", "") for j in labs.values() if j]
        last = max(times) if times else ""

        if not labs:
            verdict = "미제출"
            missing += 1
        else:
            submitted += 1
            total_sum += got
            if got >= 180:
                verdict = "수료"
                passed += 1
            else:
                verdict = "미달"

        w.writerow([sid, names.get(sid, ""), *scores, got, pct, verdict, last])

    w.writerow([])
    avg = round(total_sum / submitted, 1) if submitted else 0
    w.writerow(["제출", submitted, "미제출", missing, "수료(180점 이상)", passed, "평균", avg])

# ---- 항목별 오답 --------------------------------------------------------------
fail_path = os.path.join(out_dir, f"항목별_오답_{today}.csv")
with open(fail_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["일차", "채점 항목", "실패 인원"])
    for lab in ("day1", "day2", "day3"):
        for item, cnt in sorted(item_fail[lab].items(), key=lambda x: -x[1]):
            w.writerow([lab, item, cnt])

# ---- 화면 요약 ----------------------------------------------------------------
print(f"학생 {len(order)}명 / 제출 {submitted}명 / 미제출 {missing}명")
print(f"평균 {avg}점 · 수료(180점 이상) {passed}명")
print("")
print("가장 많이 틀린 항목")
flat = [(lab, item, cnt) for lab in item_fail for item, cnt in item_fail[lab].items()]
for lab, item, cnt in sorted(flat, key=lambda x: -x[2])[:8]:
    print(f"  {cnt:>3}명  [{lab}] {item}")
print("")
print(f"성적표      : {grade_path}")
print(f"항목별 오답 : {fail_path}")
PY
