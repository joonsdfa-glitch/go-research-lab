"""
server_colab_09.py  —  Google Colab + GPU용 서버
server_09.py (로컬 Windows)와 로직은 동일하고
아래 세 가지만 다릅니다:
  1. 경로: Colab 환경 기준 (/content/katago/...)
  2. KataGo 실행: CUDA(GPU) 바이너리 사용
  3. ngrok: 공개 URL 자동 출력 (Colab 노트북에서 호출)

사용법 (Colab 노트북):
  !python server_colab_09.py &
  또는 노트북 셀에서 직접 run_server() 호출
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import re
import time
import threading
import os

app = Flask(__name__)
CORS(app)  # 모든 origin 허용 (GitHub Pages → Colab 요청 허용)

# ── 경로 설정 (Colab 환경) ──────────────────────────────────────────
# 노트북 셀에서 KataGo를 /content/katago/ 에 설치한다고 가정
# 실제 설치 경로가 다르면 아래만 수정하면 됩니다
KATAGO_PATH = "/content/katago/katago"
CONFIG_PATH = "/content/katago/default_gtp.cfg"
MODEL_PATH  = "/content/katago/model.bin.gz"

MIN_CANDIDATES    = 3
MAX_CANDIDATES    = 5
MAX_CANDIDATES_RG = 10
MAX_WAIT_SECS     = 8.0
DEFAULT_LZ_VISITS = 400
SIZE              = 19

# AI 강도 테이블 (server_09.py와 동일)
LEVEL_TABLE = {
    1:  (1,   -3.0,  0.40),  # 18급
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

# ── KataGo 프로세스 실행 ────────────────────────────────────────────
def start_katago():
    """KataGo GTP 프로세스 시작. 실행 파일이 없으면 None 반환."""
    if not os.path.exists(KATAGO_PATH):
        print(f"❌ KataGo 실행 파일 없음: {KATAGO_PATH}")
        print("   노트북 셀에서 KataGo를 먼저 설치하세요.")
        return None
    if not os.path.exists(MODEL_PATH):
        print(f"❌ 모델 파일 없음: {MODEL_PATH}")
        return None
    try:
        proc = subprocess.Popen(
            [KATAGO_PATH, "gtp", "-config", CONFIG_PATH, "-model", MODEL_PATH],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        print("✅ KataGo 엔진 로드 성공!")
        return proc
    except Exception as e:
        print(f"❌ 엔진 로드 실패: {e}")
        return None

katago = start_katago()
_lock  = threading.Lock()


# ── GTP 유틸 (server_09.py와 동일) ─────────────────────────────────
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
        if stripped.startswith("="):
            content = stripped[1:].strip()
            if content:
                print(f"  [GTP <<] {stripped}")
                return stripped
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
        m_move   = re.search(r'\bmove (\S+)',          block)
        m_wr     = re.search(r'\bwinrate ([\d.]+)',    block)
        m_visits = re.search(r'\bvisits (\d+)',        block)
        m_score  = re.search(r'\bscoreLead ([-\d.]+)', block)
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
        well = sum(1 for v in best.values() if v["visits"] >= 5)
        if well >= MIN_CANDIDATES:
            break
    katago.stdin.write("stop\n")
    katago.stdin.flush()
    drain_pending(0.5)
    result = sorted(best.values(), key=lambda x: x["visits"], reverse=True)
    print(f"  [kata] 후보: { {r['move']: r['visits'] for r in result[:6]} }")
    return result[:max_cands]


def run_kata_analyze_extended(color: str, lz_visits: int, max_cands: int) -> list[dict]:
    wait_secs = {200: 3.0, 400: 5.0, 800: 10.0}.get(lz_visits, 5.0)
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
    return result[:max_cands]


# ── /analyze ────────────────────────────────────────────────────────
@app.route('/analyze', methods=['POST'])
def analyze():
    with _lock:
        data        = request.json
        moves       = data.get('moves', [])
        lz_visits   = int(data.get('lz_visits', DEFAULT_LZ_VISITS))
        region_mode = bool(data.get('region_mode', False))
        region      = data.get('region', None)

        max_cands = MAX_CANDIDATES_RG if region_mode else MAX_CANDIDATES
        print(f"\n[서버] 분석 요청 ({len(moves)}수, region={region_mode})")

        send_command("clear_board")
        send_command("komi 6.5")
        for color, move in moves:
            send_command(f"play {color} {move}")

        color_to_move = "black" if (len(moves) % 2 == 0) else "white"

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

        in_region_candidates = []
        if region_mode and region:
            def gtp_to_rc(gtp):
                col_map = "ABCDEFGHJKLMNOPQRST"
                c = col_map.find(gtp[0].upper())
                r = SIZE - int(gtp[1:])
                return r, c
            def is_in_region(move):
                r, c = gtp_to_rc(move)
                return (region['r1'] <= r <= region['r2'] and
                        region['c1'] <= c <= region['c2'])
            in_region_candidates = [c for c in candidates if is_in_region(c['move'])]
            if len(in_region_candidates) < MIN_CANDIDATES:
                katago.stdin.write(f"kata-analyze {color_to_move} interval 100 ownership true\n")
                katago.stdin.flush()
                extra_best = dict(best)
                deadline2 = time.time() + 12.0
                while time.time() < deadline2:
                    line = katago.stdout.readline()
                    if not line: break
                    line = line.strip()
                    if line.startswith("info move"):
                        extra_best.update(parse_blocks(line, 50))
                    if sum(1 for mv in extra_best if is_in_region(mv)) >= MIN_CANDIDATES:
                        break
                katago.stdin.write("stop\n")
                katago.stdin.flush()
                drain_pending(0.5)
                all_cands = sorted(extra_best.values(), key=lambda x: x["visits"], reverse=True)
                in_region_candidates = [c for c in all_cands if is_in_region(c['move'])]
                candidates = all_cands[:max_cands]
                best_cand = candidates[0]
                sl = best_cand.get("score_lead")
                score_lead_black = (round(sl, 1) if color_to_move == "black" else round(-sl, 1)) \
                                   if sl is not None else None

        return jsonify({
            "status":               "success",
            "best_move":            best_cand["move"],
            "winrate":              best_cand["winrate"],
            "score_lead_black":     score_lead_black,
            "candidates":           candidates,
            "in_region_candidates": in_region_candidates[:3],
            "ownership":            ownership
        })


# ── /genmove ────────────────────────────────────────────────────────
@app.route('/genmove', methods=['POST'])
def genmove():
    with _lock:
        data     = request.json
        moves    = data.get('moves', [])
        level    = int(data.get('level', 18))
        komi     = float(data.get('komi', 6.5))
        handicap = int(data.get('handicap', 0))
        visits, pda, noise = LEVEL_TABLE.get(level, (400, 0.0, 0.0))

        print(f"\n[서버] genmove (level={level}, visits={visits}, pda={pda}, noise={noise}, komi={komi})")

        send_command("clear_board")
        send_command(f"komi {komi}")
        if handicap >= 2 and len(moves) <= handicap:
            send_command(f"place_free_handicap {handicap}")
        else:
            for color, move in moves:
                send_command(f"play {color} {move}")

        color_to_move = "black" if (len(moves) % 2 == 0) else "white"
        next_color    = "white" if color_to_move == "black" else "black"

        try: send_command(f"kata-set-param maxVisits {visits}")
        except: pass
        try:
            send_command(f"kata-set-param playoutDoublingAdvantage {pda}")
            send_command(f"kata-set-param playoutDoublingAdvantagePla {'b' if color_to_move == 'black' else 'w'}")
        except: pass
        try:
            if noise > 0:
                send_command(f"kata-set-param wideRootNoise {noise}")
        except: pass

        resp     = send_genmove(color_to_move)
        move_raw = resp.replace("=", "").strip().upper()

        try: send_command("kata-set-param maxVisits 100000")
        except: pass
        try: send_command("kata-set-param playoutDoublingAdvantage 0.0")
        except: pass
        try: send_command("kata-set-param wideRootNoise 0.0")
        except: pass

        if not move_raw or move_raw.startswith("?"):
            return jsonify({"status": "error", "message": "genmove 실패"}), 500

        if move_raw not in ("PASS", "RESIGN"):
            send_command(f"play {color_to_move} {move_raw}")

        winrate = score_lead_b = ownership = None
        try:
            katago.stdin.write(f"kata-analyze {next_color} interval 100 ownership true\n")
            katago.stdin.flush()
            deadline = time.time() + 3.0
            while time.time() < deadline:
                line = katago.stdout.readline()
                if not line: break
                line = line.strip()
                if line.startswith("info move"):
                    blocks = parse_blocks(line, 1)
                    if blocks:
                        top = next(iter(blocks.values()))
                        wr_raw = top["winrate"]
                        sl_raw = top.get("score_lead")
                        winrate      = wr_raw if next_color == "black" else round(100 - wr_raw, 1)
                        score_lead_b = (round(sl_raw, 1) if next_color == "black" else round(-sl_raw, 1)) \
                                       if sl_raw is not None else None
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
            print(f"  [genmove] winrate 수집 실패: {e}")

        return jsonify({
            "status":           "success",
            "move":             move_raw,
            "winrate":          winrate,
            "score_lead_black": score_lead_b,
            "ownership":        ownership
        })


# ── /score ──────────────────────────────────────────────────────────
@app.route('/score', methods=['POST'])
def score():
    with _lock:
        data  = request.json
        moves = data.get('moves', [])
        komi  = float(data.get('komi', 6.5))

        send_command("clear_board")
        send_command(f"komi {komi}")
        for color, move in moves:
            send_command(f"play {color} {move}")

        resp      = send_command("final_score")
        score_str = resp.replace("=", "").strip()

        winner = "draw"; margin = 0.0
        if score_str.startswith("B+"):
            winner = "black"; margin = float(score_str[2:])
        elif score_str.startswith("W+"):
            winner = "white"; margin = float(score_str[2:])

        if winner == "black":
            black_score = round(180.5 + margin / 2, 1)
            white_score = round(180.5 - margin / 2, 1)
        elif winner == "white":
            black_score = round(180.5 - margin / 2, 1)
            white_score = round(180.5 + margin / 2, 1)
        else:
            black_score = white_score = 180.5

        return jsonify({
            "status": "success", "raw": score_str,
            "winner": winner,    "margin": margin,
            "black":  black_score, "white": white_score, "komi": komi
        })


# ── 서버 시작 ────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("🚀 Go Research Lab 서버 (Colab) 가동 중... (포트: 5000)")
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
