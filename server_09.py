from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import re
import time
import threading

app = Flask(__name__)
CORS(app)

# --- 경로 설정 ---
KATAGO_PATH = r"C:\Users\joon4\Desktop\go project\katago.exe"
CONFIG_PATH = r"C:\Users\joon4\Desktop\go project\default_gtp.cfg"
MODEL_PATH  = r"C:\Users\joon4\Desktop\go project\default_model.bin.gz"

MIN_CANDIDATES    = 3
MAX_CANDIDATES    = 5
MAX_CANDIDATES_RG = 10
MAX_WAIT_SECS     = 8.0
DEFAULT_LZ_VISITS = 400
SIZE              = 19

# AI 강도 테이블: (visits, playoutDoublingAdvantage, wideRootNoise)
# pda: 음수일수록 AI가 스스로 불리하게 판단 (-3.0이 최대)
# wideRootNoise: 높을수록 랜덤 착수 비율 증가 (실수 유도, 0.0~0.4)
LEVEL_TABLE = {
    #        visits  pda    noise
    1:  (1,   -3.0,  0.40),  # 18급 (완전 초보)
    2:  (1,   -3.0,  0.35),  # 17급
    3:  (1,   -3.0,  0.30),  # 16급
    4:  (2,   -3.0,  0.25),  # 15급
    5:  (2,   -3.0,  0.20),  # 14급
    6:  (3,   -3.0,  0.15),  # 13급
    7:  (4,   -3.0,  0.10),  # 12급
    8:  (6,   -3.0,  0.05),  # 11급
    9:  (8,   -2.8,  0.02),  # 10급
    10: (12,  -2.5,  0.0),   # 9급
    11: (18,  -2.2,  0.0),   # 8급
    12: (28,  -1.8,  0.0),   # 7급
    13: (45,  -1.4,  0.0),   # 6급
    14: (70,  -1.0,  0.0),   # 5급
    15: (110, -0.7,  0.0),   # 4급
    16: (170, -0.4,  0.0),   # 3급
    17: (260, -0.2,  0.0),   # 2급
    18: (400,  0.0,  0.0),   # 1급
    19: (600,  0.0,  0.0),   # 1단
    20: (900,  0.0,  0.0),   # 2단
    21: (1300, 0.0,  0.0),   # 3단
    22: (1900, 0.0,  0.0),   # 4단
    23: (2800, 0.0,  0.0),   # 5단
    24: (4000, 0.0,  0.0),   # 6단
    25: (5500, 0.0,  0.0),   # 7단
    26: (7500, 0.0,  0.0),   # 8단
    27: (10000,0.0,  0.0),   # 9단 (최강)
}

# ── 카타고 프로세스 실행 ────────────────────────────────────────────
try:
    katago = subprocess.Popen(
        [KATAGO_PATH, "gtp", "-config", CONFIG_PATH, "-model", MODEL_PATH],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )
    print("✅ 카타고 엔진 로드 성공!")
except Exception as e:
    print(f"❌ 엔진 로드 실패: {e}")
    katago = None

_lock = threading.Lock()


def send_command(command: str) -> str:
    print(f"  [GTP >>] {command.strip()}")
    katago.stdin.write(command + "\n")
    katago.stdin.flush()
    lines = []
    while True:
        line = katago.stdout.readline()
        if line == "":
            break
        stripped = line.rstrip("\n")
        if stripped == "":
            if lines:
                break
            continue
        lines.append(stripped)
    response = "\n".join(lines)
    print(f"  [GTP <<] {response[:160]}")
    return response


def send_genmove(color: str, timeout: float = 60.0) -> str:
    """genmove 전용: 실제 착수 좌표가 포함된 응답이 올 때까지 대기."""
    print(f"  [GTP >>] genmove {color}")
    katago.stdin.write(f"genmove {color}\n")
    katago.stdin.flush()

    deadline = time.time() + timeout
    while time.time() < deadline:
        line = katago.stdout.readline()
        if not line:
            break
        stripped = line.rstrip("\n").strip()
        if not stripped:
            continue
        # "= Q4", "= PASS", "= resign" 처럼 = 뒤에 내용이 있는 것만 인정
        if stripped.startswith("="):
            content = stripped[1:].strip()
            if content:  # ← 빈 "=" 는 무시, 내용 있을 때만 리턴
                print(f"  [GTP <<] {stripped}")
                return stripped
            # 빈 "=" 은 계속 대기
            continue
        if stripped.startswith("?"):
            print(f"  [GTP <<] {stripped}")
            return stripped
    return ""


def drain_pending(timeout: float = 0.4):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            line = katago.stdout.readline()
            if not line or line.strip() == "":
                break
        except Exception:
            break


def parse_pv(block: str, move: str) -> list[str]:
    m = re.search(r'\bpv\s+((?:[A-Ta-t]\d{1,2}\s*)+)', block)
    if not m:
        return []
    raw = m.group(1).upper().split()
    valid = [mv for mv in raw if re.match(r'^[A-T]\d{1,2}$', mv)]
    if valid and valid[0] == move.upper():
        valid = valid[1:]
    return valid[:8]


def parse_blocks(line: str, max_cands: int) -> dict:
    blocks = re.split(r'(?=\binfo move )', line)
    result = {}
    for block in blocks:
        m_move   = re.search(r'\bmove (\S+)',           block)
        m_wr     = re.search(r'\bwinrate ([\d.]+)',     block)
        m_visits = re.search(r'\bvisits (\d+)',         block)
        m_score  = re.search(r'\bscoreLead ([-\d.]+)',  block)
        if not (m_move and m_wr):
            continue
        mv = m_move.group(1).upper()
        if mv in ('PASS', 'RESIGN'):
            continue
        pv = parse_pv(block, mv)
        result[mv] = {
            "move":       mv,
            "winrate":    round(float(m_wr.group(1)) * 100, 1),
            "visits":     int(m_visits.group(1)) if m_visits else 0,
            "score_lead": round(float(m_score.group(1)), 1) if m_score else None,
            "pv":         pv,
        }
    return result


def run_kata_analyze(color: str, max_cands: int) -> list[dict]:
    katago.stdin.write(f"kata-analyze {color} interval 100\n")
    katago.stdin.flush()

    best: dict[str, dict] = {}
    deadline = time.time() + MAX_WAIT_SECS

    while time.time() < deadline:
        line = katago.stdout.readline()
        if not line:
            break
        line = line.strip()
        if line.startswith("?"):
            drain_pending(); return []
        if not line.startswith("info move"):
            continue

        best.update(parse_blocks(line, max_cands))

        if len(best) >= 1 and not hasattr(run_kata_analyze, '_logged'):
            run_kata_analyze._logged = True
            print(f"  [RAW-LINE] {line[:400]}")

        well = sum(1 for v in best.values() if v["visits"] >= 5)
        if well >= MIN_CANDIDATES:
            break

    katago.stdin.write("stop\n")
    katago.stdin.flush()
    drain_pending(0.5)

    result = sorted(best.values(), key=lambda x: x["visits"], reverse=True)
    print(f"  [kata] 후보: { {r['move']: r['visits'] for r in result[:6]} }")
    for r in result[:3]:
        print(f"    pv[{r['move']}]: {r['pv']}")
    return result[:max_cands]


def run_kata_analyze_extended(color: str, lz_visits: int, max_cands: int) -> list[dict]:
    wait_secs = {200: 3.0, 400: 5.0, 800: 10.0}.get(lz_visits, 5.0)
    print(f"  [kata-ext] {wait_secs}초 대기")

    katago.stdin.write(f"kata-analyze {color} interval 100\n")
    katago.stdin.flush()

    best: dict[str, dict] = {}
    deadline = time.time() + wait_secs

    while time.time() < deadline:
        line = katago.stdout.readline()
        if not line:
            break
        line = line.strip()
        if line.startswith("?"):
            drain_pending(); return []
        if not line.startswith("info move"):
            continue

        best.update(parse_blocks(line, max_cands))

        well = sum(1 for v in best.values() if v["visits"] >= 3)
        if well >= MIN_CANDIDATES:
            break

    katago.stdin.write("stop\n")
    katago.stdin.flush()
    drain_pending(0.5)

    result = sorted(best.values(), key=lambda x: x["visits"], reverse=True)
    print(f"  [kata-ext] 후보: { {r['move']: r['visits'] for r in result[:6]} }")
    return result[:max_cands]


# ── /analyze (기존 연구 모드용) ──────────────────────────────────────
@app.route('/analyze', methods=['POST'])
def analyze():
    with _lock:
        data        = request.json
        moves       = data.get('moves', [])
        lz_visits   = int(data.get('lz_visits', DEFAULT_LZ_VISITS))
        region_mode = bool(data.get('region_mode', False))
        region      = data.get('region', None)  # {r1,c1,r2,c2} 영역 좌표

        max_cands = MAX_CANDIDATES_RG if region_mode else MAX_CANDIDATES
        print(f"\n[서버] 분석 요청 (총 {len(moves)}수, max_cands={max_cands}, region={region_mode}, rect={region})")

        send_command("clear_board")
        send_command("komi 6.5")  # ★ 덤 6.5집
        for color, move in moves:
            send_command(f"play {color} {move}")

        color_to_move = "black" if (len(moves) % 2 == 0) else "white"

        # ★ ownership true 포함해서 분석
        ownership = None
        katago.stdin.write(f"kata-analyze {color_to_move} interval 100 ownership true\n")
        katago.stdin.flush()

        best: dict = {}
        deadline = time.time() + MAX_WAIT_SECS
        while time.time() < deadline:
            line = katago.stdout.readline()
            if not line: break
            line = line.strip()
            if line.startswith("?"): drain_pending(); break
            if line.startswith("info move"):
                best.update(parse_blocks(line, max_cands))
            if "ownership" in line and ownership is None:
                m = re.search(r'ownership\s+([-\d.\s]+)', line)
                if m:
                    vals = [round(float(v), 3) for v in m.group(1).split()]
                    if len(vals) == SIZE * SIZE:
                        ownership = vals
            well = sum(1 for v in best.values() if v["visits"] >= 5)
            if well >= MIN_CANDIDATES and ownership is not None:
                break

        katago.stdin.write("stop\n")
        katago.stdin.flush()
        drain_pending(0.5)

        candidates = sorted(best.values(), key=lambda x: x["visits"], reverse=True)

        if len(candidates) < MIN_CANDIDATES:
            print(f"  [보충] 후보 {len(candidates)}개 → 연장")
            extra = run_kata_analyze_extended(color_to_move, lz_visits, max_cands)
            existing = {c["move"] for c in candidates}
            for c in extra:
                if c["move"] not in existing:
                    candidates.append(c)
                    existing.add(c["move"])
                if len(candidates) >= max_cands:
                    break
            candidates.sort(key=lambda x: x["visits"], reverse=True)

        if not candidates:
            candidates = [{"move": "PASS", "winrate": 50.0, "visits": 0, "score_lead": None, "pv": []}]

        candidates = candidates[:max_cands]
        best_cand = candidates[0]
        sl = best_cand.get("score_lead")
        score_lead_black = (round(sl, 1) if color_to_move == "black" else round(-sl, 1)) \
                           if sl is not None else None

        # ★ 영역 내 후보 보장: region이 있으면 영역 안 후보가 충분한지 확인
        in_region_candidates = []
        if region_mode and region:
            def gtp_to_rc(gtp):
                gtp = gtp.upper()
                col_map = "ABCDEFGHJKLMNOPQRST"
                c = col_map.find(gtp[0])
                r = SIZE - int(gtp[1:])
                return r, c

            def is_in_region(move):
                r, c = gtp_to_rc(move)
                return (region['r1'] <= r <= region['r2'] and
                        region['c1'] <= c <= region['c2'])

            in_region_candidates = [c for c in candidates if is_in_region(c['move'])]

            # 영역 내 후보가 MIN_CANDIDATES보다 적으면 더 오래 분석
            if len(in_region_candidates) < MIN_CANDIDATES:
                print(f"  [region] 영역 내 후보 {len(in_region_candidates)}개 → 연장 분석")
                katago.stdin.write(f"kata-analyze {color_to_move} interval 100 ownership true\n")
                katago.stdin.flush()
                extra_best = dict(best)  # 기존 결과 유지
                deadline2 = time.time() + 12.0  # 더 오래 대기
                while time.time() < deadline2:
                    line = katago.stdout.readline()
                    if not line: break
                    line = line.strip()
                    if line.startswith("info move"):
                        extra_best.update(parse_blocks(line, 50))  # 많이 수집
                    in_count = sum(1 for mv in extra_best if is_in_region(mv))
                    if in_count >= MIN_CANDIDATES:
                        break
                katago.stdin.write("stop\n")
                katago.stdin.flush()
                drain_pending(0.5)

                all_cands = sorted(extra_best.values(), key=lambda x: x["visits"], reverse=True)
                in_region_candidates = [c for c in all_cands if is_in_region(c['move'])]
                # 전체 candidates도 갱신
                candidates = all_cands[:max_cands]
                best_cand  = candidates[0]
                sl = best_cand.get("score_lead")
                score_lead_black = (round(sl, 1) if color_to_move == "black" else round(-sl, 1)) \
                                   if sl is not None else None

            print(f"  [region] 영역 내 후보: {[c['move'] for c in in_region_candidates[:5]]}")

        print(f"[서버] 최선수:{best_cand['move']} 승률:{best_cand['winrate']}% 집수:{score_lead_black} 후보:{len(candidates)}개 ownership:{'있음' if ownership else '없음'}")

        return jsonify({
            "status":                "success",
            "best_move":             best_cand["move"],
            "winrate":               best_cand["winrate"],
            "score_lead_black":      score_lead_black,
            "candidates":            candidates,
            "in_region_candidates":  in_region_candidates[:3],  # ★ 영역 내 상위 3개 별도 반환
            "ownership":             ownership
        })


# ── /genmove (AI 대국 모드용) ────────────────────────────────────────
@app.route('/genmove', methods=['POST'])
def genmove():
    """
    AI가 다음 수를 생성해서 반환.
    body: { moves: [[color, coord], ...], level: 1~9 }
    return: { move: "Q16" | "PASS" | "RESIGN", winrate, score_lead_black }
    """
    with _lock:
        data     = request.json
        moves    = data.get('moves', [])
        level    = int(data.get('level', 18))
        komi     = float(data.get('komi', 6.5))
        handicap = int(data.get('handicap', 0))
        visits, pda, noise = LEVEL_TABLE.get(level, (400, 0.0, 0.0))

        print(f"\n[서버] genmove 요청 (level={level}, visits={visits}, pda={pda}, noise={noise}, komi={komi}, hc={handicap})")

        # 보드 세팅
        send_command("clear_board")
        send_command(f"komi {komi}")
        # ★ 접바둑: place_free_handicap으로 KataGo 내부 보드에도 핸디캡 반영
        if handicap >= 2 and len(moves) <= handicap:
            send_command(f"place_free_handicap {handicap}")
        else:
            for color, move in moves:
                send_command(f"play {color} {move}")

        color_to_move = "black" if (len(moves) % 2 == 0) else "white"
        next_color    = "white" if color_to_move == "black" else "black"

        # ★ 강도 조절: visits + pda + wideRootNoise 조합
        try:
            send_command(f"kata-set-param maxVisits {visits}")
        except Exception:
            pass
        try:
            send_command(f"kata-set-param playoutDoublingAdvantage {pda}")
            send_command(f"kata-set-param playoutDoublingAdvantagePla {'b' if color_to_move == 'black' else 'w'}")
        except Exception:
            pass
        try:
            if noise > 0:
                send_command(f"kata-set-param wideRootNoise {noise}")
        except Exception:
            pass

        # AI 착수 생성 (전용 함수로 충분히 대기)
        resp = send_genmove(color_to_move)

        # 응답 파싱: "= Q16" 또는 "= PASS" 또는 "= resign"
        move_raw = resp.replace("=", "").strip().upper()

        # ★ 파라미터 복원
        try:
            send_command("kata-set-param maxVisits 100000")
        except Exception:
            pass
        try:
            send_command("kata-set-param playoutDoublingAdvantage 0.0")
        except Exception:
            pass
        try:
            send_command("kata-set-param wideRootNoise 0.0")
        except Exception:
            pass

        if not move_raw or move_raw.startswith("?"):
            return jsonify({"status": "error", "message": "genmove 실패"}), 500

        # ★ AI 착수 후 보드에 반영 (play 명령으로 동기화)
        if move_raw not in ("PASS", "RESIGN"):
            send_command(f"play {color_to_move} {move_raw}")

        # genmove 후 winrate + ownership 수집
        winrate      = None
        score_lead_b = None
        ownership    = None
        try:
            # ★ AI 착수 후 차례(next_color) 기준으로 분석
            katago.stdin.write(f"kata-analyze {next_color} interval 100 ownership true\n")
            katago.stdin.flush()
            deadline = time.time() + 3.0
            while time.time() < deadline:
                line = katago.stdout.readline()
                if not line:
                    break
                line = line.strip()
                if line.startswith("info move"):
                    blocks = parse_blocks(line, 1)
                    if blocks:
                        top = next(iter(blocks.values()))
                        wr_raw = top["winrate"]
                        sl_raw = top.get("score_lead")
                        # next_color 기준 winrate → 흑 기준으로 변환
                        winrate      = wr_raw if next_color == "black" else round(100 - wr_raw, 1)
                        score_lead_b = (round(sl_raw, 1) if next_color == "black" else round(-sl_raw, 1)) \
                                       if sl_raw is not None else None
                # ownership 파싱: "ownership val1 val2 ... val361"
                if "ownership" in line and ownership is None:
                    m = re.search(r'ownership\s+([-\d.\s]+)', line)
                    if m:
                        vals = [round(float(v), 3) for v in m.group(1).split()]
                        if len(vals) == SIZE * SIZE:
                            ownership = vals
                if winrate is not None and ownership is not None:
                    break
            katago.stdin.write("stop\n")
            katago.stdin.flush()
            drain_pending(0.3)
        except Exception as e:
            print(f"  [genmove] winrate/ownership 수집 실패: {e}")

        print(f"[서버] AI 착수: {move_raw}  승률(흑기준): {winrate}%  집차이: {score_lead_b}  ownership: {'있음' if ownership else '없음'}")

        return jsonify({
            "status":           "success",
            "move":             move_raw,
            "winrate":          winrate,
            "score_lead_black": score_lead_b,
            "ownership":        ownership  # 19×19=361개, 흑=+1, 백=-1
        })




# ── /score (계가) ────────────────────────────────────────────────────
@app.route('/score', methods=['POST'])
def score():
    """
    현재 국면의 계가 결과 반환.
    KataGo final_score 명령 사용 (중국룰 기반 집 계산).
    body: { moves: [[color, coord], ...], komi: 6.5 }
    return: { black, white, winner, margin, komi }
    """
    with _lock:
        data  = request.json
        moves = data.get('moves', [])
        komi  = float(data.get('komi', 6.5))

        print(f"\n[서버] 계가 요청 (총 {len(moves)}수, komi={komi})")

        send_command("clear_board")
        send_command(f"komi {komi}")
        for color, move in moves:
            send_command(f"play {color} {move}")

        # final_score: KataGo가 사석 처리 후 점수 계산
        resp = send_command("final_score")
        # 응답 예: "= B+6.5" 또는 "= W+3.5" 또는 "= 0" (무승부)
        score_str = resp.replace("=", "").strip()

        print(f"  [score] final_score 응답: {score_str}")

        # 파싱
        winner = None
        margin = 0.0
        black_score = 0.0
        white_score = 0.0

        if score_str.startswith("B+"):
            winner = "black"
            margin = float(score_str[2:])
        elif score_str.startswith("W+"):
            winner = "white"
            margin = float(score_str[2:])
        else:
            # 무승부 또는 파싱 실패
            winner = "draw"
            margin = 0.0

        # 흑·백 점수 역산 (집+사석+덤 기준)
        # final_score는 덤을 포함한 순 차이값이므로:
        # margin = black_total - white_total  (흑 승 시 양수)
        # 대략적인 집수: 전체 361집을 반씩 나눈 기준으로 계산
        total_stones = len([m for m in moves])
        # ownership 기반 추정치 대신 scoreLead 방식 사용
        if winner == "black":
            black_score = round(180.5 + margin / 2, 1)
            white_score = round(180.5 - margin / 2, 1)
        elif winner == "white":
            black_score = round(180.5 - margin / 2, 1)
            white_score = round(180.5 + margin / 2, 1)
        else:
            black_score = white_score = 180.5

        print(f"[서버] 계가 결과: {score_str} → 흑:{black_score} 백:{white_score}")

        return jsonify({
            "status":  "success",
            "raw":     score_str,
            "winner":  winner,
            "margin":  margin,
            "black":   black_score,
            "white":   white_score,
            "komi":    komi
        })


if __name__ == '__main__':
    print("🚀 AI 중계 서버 가동 중... (포트: 5000)")
    app.run(host='0.0.0.0', port=5000, debug=False)