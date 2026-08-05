#!/usr/bin/env python3
"""메모요 Play Store 스크린샷 합성 (한글 캡션 헤더 + 레터박스).

integration_test 하니스(screenshot_test.dart)가 부팅된 기기에서 실제 화면을
build/screenshots/<name>.png 로 캡처한 뒤, 이 스크립트로 1080x1920 Play-safe
캔버스에 amber 캡션 헤더 + 스크린샷을 합성한다. (목업 합성 X — 실제 렌더 캡처.)

사용:
  python3 scripts/compose_store_screenshots.py \
    --raw build/screenshots \
    --out store/screenshots/ko

하니스 raw 파일명 → 최종 스토어 파일명/캡션 매핑은 SCENES 에 고정.
"""
import argparse
import os
from PIL import Image, ImageDraw, ImageFont

# Play-safe 캔버스 (≤2:1, 9:16)
CANVAS = (1080, 1920)
BG = (16, 16, 18)
AMBER = (242, 193, 78)
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
FONT_BOLD = 6      # AppleSDGothicNeo Bold

# 스크린샷 배치 (앱 화면 자체에 "vdev · 강대종" 푸터 워터마크가 포함됨 — 합성 시 별도 푸터 X)
SHOT_TOP = 235
SHOT_MAX_W = 860
SHOT_MAX_H = 1560
# 캡션
CAP_Y = 100        # 캡션 수직 중심
CAP_SIZE = 54
UNDERLINE_Y = 192
UNDERLINE_W = 118
UNDERLINE_H = 7

# 하니스 raw 이름 → (최종 파일명, 캡션)
#
# ★출고본에 없는 기능의 컷 3장 제거 — T-260805-082.
#   스토어 캡처는 「우리가 파는 것」의 목록이다. 앱에서 사라진 기능이 여기 남으면
#   장수만 맞고 내용이 거짓인 세트가 나간다. 뺀 셋(raw 키)과 근거:
#     06-ai-summary      → 유료 요약 기능은 T-260804-062 로 호출 경로째 제거됐다.
#     07-semantic-search → kSemanticSearchEnabled(기본 false)로 잠겨 있고 그 define 을
#                          주입하는 곳이 android/·scripts/ 어디에도 ★0건 = 출고본에 UI 없음
#                          (T-260804-086 「온디바이스 될 때까지 숨긴다」).
#     04-premium         → premium_monthly 상품이 T-260805-076 으로 코드에서 사라졌고
#                          전 스토어 판매중지다.
#   ★제거된 3줄의 원문은 git 이력이 보관한다 — 여기 인용을 남기지 않는 이유는,
#   폐지된 판매 문구를 파일에 다시 심으면 회귀 스캔이 그것부터 잡기 때문이다.
#
#   ★파일명은 재번호하지 않는다. 남은 4장의 이름순 정렬이 이미 노출 순서이고,
#   1~4 로 다시 매기면 스토어 기존 자산 대조와 git 이력만 흔들린다(원칙 9 국소·단순).
#   번호 구멍(03·04·05 결번)은 결함이 아니라 ★무엇을 뺐는지 남긴 자국이다.
SCENES = [
    ("01-main",     "01_dark_main.png",    "생각난 순간 바로 기록"),
    ("05-edit",     "02_quick_write.png",  "제목 없이 빠르게 쓰기"),
    ("03-backup",   "06_drive_backup.png", "내 Drive에 간편하게 백업"),
    # ★캡션 교체 (T-260805-082) — 이 화면이 실제로 보여주는 것은 광고제거 단품·
    #   구매 복원·정책이다. 팔지 않는 것을 캡션이 부르면 안 된다.
    ("02-settings", "07_settings.png",     "광고 제거·복원·정책까지 투명하게"),
]


def fit(size, max_w, max_h):
    w, h = size
    s = min(max_w / w, max_h / h)
    return int(round(w * s)), int(round(h * s))


def compose(raw_path, caption, out_path):
    canvas = Image.new("RGB", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    cap_font = ImageFont.truetype(FONT, CAP_SIZE, index=FONT_BOLD)

    # 캡션 (가운데 정렬)
    bbox = draw.textbbox((0, 0), caption, font=cap_font)
    cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((CANVAS[0] - cw) / 2 - bbox[0], CAP_Y - ch / 2 - bbox[1]),
              caption, font=cap_font, fill=AMBER)

    # 언더라인 (가운데, 라운드)
    x0 = (CANVAS[0] - UNDERLINE_W) / 2
    draw.rounded_rectangle(
        [x0, UNDERLINE_Y, x0 + UNDERLINE_W, UNDERLINE_Y + UNDERLINE_H],
        radius=UNDERLINE_H / 2, fill=AMBER)

    # 스크린샷 (가운데, 상단정렬, 비율 유지)
    shot = Image.open(raw_path).convert("RGB")
    sw, sh = fit(shot.size, SHOT_MAX_W, SHOT_MAX_H)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    canvas.paste(shot, ((CANVAS[0] - sw) // 2, SHOT_TOP))

    canvas.save(out_path)
    return canvas.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="build/screenshots",
                    help="하니스 raw 캡처 디렉토리")
    ap.add_argument("--out", default="store/screenshots/ko",
                    help="최종 합성본 출력 디렉토리")
    ap.add_argument("--raw-out", default=None,
                    help="raw 원본 복사 디렉토리 (옵션)")
    ap.add_argument("--ios-out", default=None,
                    help="App Store용 원본 크기 RGB 복사 디렉토리 (옵션)")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    if args.raw_out:
        os.makedirs(args.raw_out, exist_ok=True)
    if args.ios_out:
        os.makedirs(args.ios_out, exist_ok=True)

    for raw_name, out_name, caption in SCENES:
        raw_path = os.path.join(args.raw, raw_name + ".png")
        if not os.path.exists(raw_path):
            raise SystemExit(f"raw 없음: {raw_path}")
        out_path = os.path.join(args.out, out_name)
        size = compose(raw_path, caption, out_path)
        print(f"  {out_name}  {size}  <- {raw_name}.png  ({caption})")
        if args.raw_out:
            Image.open(raw_path).save(os.path.join(args.raw_out, raw_name + ".png"))
        if args.ios_out:
            Image.open(raw_path).convert("RGB").save(
                os.path.join(args.ios_out, out_name)
            )


if __name__ == "__main__":
    main()
