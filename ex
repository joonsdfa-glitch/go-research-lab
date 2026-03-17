<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>Go Research Lab v0.9</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600;700&family=Noto+Sans+KR:wght@400;500;700&display=swap');

        :root {
            --bg:     #111416; --panel:  #1c1f23; --border: #2e3338;
            --accent: #f0c040; --cyan:   #00e5ff; --dim:    #555;
            --win-b:  #64dd17; --win-w:  #ff6e40;
            --c1: #00e5ff; --c2: #ffca28;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Noto Sans KR', sans-serif;
            background: var(--bg); color: #ddd;
            display: flex; flex-direction: column; align-items: center;
            padding: 18px 14px 40px; min-height: 100vh;
        }
        header { display: flex; align-items: baseline; gap: 12px; margin-bottom: 16px; }
        header h1 { font-family: 'JetBrains Mono',monospace; font-size:1.3rem; color:var(--accent); letter-spacing:.06em; }
        header span { font-family: 'JetBrains Mono',monospace; font-size:.68rem; color:var(--dim); }

        .workspace { display: flex; gap: 16px; align-items: flex-start; }
        #canvas { cursor: cell; border-radius: 4px; flex-shrink: 0; box-shadow: 0 8px 40px rgba(0,0,0,.6); }
        #canvas.region-drag { cursor: crosshair; }

        .sidebar { width: 248px; display: flex; flex-direction: column; gap: 9px; }
        .panel { background:var(--panel); border:1px solid var(--border); border-radius:6px; padding:12px; }
        .ptitle { font-family:'JetBrains Mono',monospace; font-size:.58rem; text-transform:uppercase; letter-spacing:.14em; color:var(--dim); margin-bottom:8px; }

        /* 차례 + 네비 */
        .turn-row { display:flex; align-items:center; gap:6px; }
        #turn-stone { width:16px;height:16px;border-radius:50%;background:#111;border:1px solid #555;flex-shrink:0; }
        #turn-stone.white { background:#f0f0f0; }
        #turn-text { font-weight:700; font-size:.9rem; flex:1; }
        .nav-btns { display:flex; gap:3px; }
        .nav-btn {
            width:26px;height:26px;border:1px solid var(--border);border-radius:3px;
            background:#1a1e22;color:#aaa;font-size:.82rem;cursor:pointer;
            display:flex;align-items:center;justify-content:center;transition:background .1s,color .1s;
        }
        .nav-btn:hover { background:#2e353c;color:#fff; }
        .nav-btn:disabled { opacity:.3;cursor:default; }
        #move-counter { font-family:'JetBrains Mono',monospace;font-size:.62rem;color:var(--dim);text-align:center;margin-top:4px; }

        /* 돌 색 선택 */
        .stone-picker { display:flex; gap:4px; }
        .stone-opt {
            flex:1;padding:6px 0;text-align:center;border:1px solid var(--border);border-radius:4px;
            background:#1a1e22;color:var(--dim);font-family:'JetBrains Mono',monospace;font-size:.68rem;
            cursor:pointer;transition:all .12s;
        }
        .stone-opt:hover { background:#252a2e;color:#ccc; }
        .stone-opt.auto-active  { border-color:var(--accent);color:var(--accent);background:#2a2600;font-weight:700; }
        .stone-opt.black-active { border-color:#888;color:#fff;background:#2a2a2a;font-weight:700; }
        .stone-opt.white-active { border-color:#999;color:#111;background:#ddd;font-weight:700; }

        /* 버튼 */
        .btn {
            width:100%;padding:7px 10px;border:1px solid var(--border);border-radius:4px;
            background:#252a2e;color:#ccc;font-family:'Noto Sans KR',sans-serif;font-size:.78rem;
            cursor:pointer;text-align:left;transition:background .12s,color .12s;
        }
        .btn:hover   { background:#2e353c;color:#fff;border-color:#444; }
        .btn.active  { background:var(--accent);color:#000;border-color:var(--accent);font-weight:700; }
        .btn.primary { background:#0277bd;border-color:#0288d1;color:#fff; }
        .btn.primary:hover { background:#0288d1; }
        .btn.danger  { background:#6e1a1a;border-color:#8b2020;color:#ff8a80; }
        .btn.danger:hover  { background:#8b2020; }
        .btn.green   { background:#1b4d1b;border-color:#2e7d32;color:#a5d6a7; }
        .btn.green:hover   { background:#2e7d32;color:#fff; }
        .btn.purple  { background:#2e1040;border-color:#7b1fa2;color:#ce93d8; }
        .btn.purple:hover  { background:#4a1060;color:#fff; }
        .btn.purple.active { background:#7b1fa2;border-color:#ce93d8;color:#fff; }
        .btn.realtime-on   { background:#7b1fa2;border-color:#9c27b0;color:#fff;animation:pulse-border 1.8s ease-in-out infinite; }
        @keyframes pulse-border {
            0%,100%{ border-color:#9c27b0;box-shadow:0 0 0 0 rgba(156,39,176,0); }
            50%    { border-color:#ce93d8;box-shadow:0 0 0 4px rgba(156,39,176,.22); }
        }

        #ai-status { font-family:'JetBrains Mono',monospace;font-size:.7rem;color:var(--cyan);min-height:1em;text-align:center; }

        .speed-group { display:flex;gap:4px;width:100%; }
        .speed-btn {
            flex:1;padding:5px 0;text-align:center;border:1px solid var(--border);border-radius:4px;
            background:#1a1e22;color:var(--dim);font-family:'JetBrains Mono',monospace;font-size:.65rem;
            cursor:pointer;transition:all .12s;
        }
        .speed-btn:hover { background:#252a2e;color:#ccc; }
        .speed-btn.active { background:#1a3a4a;border-color:var(--cyan);color:var(--cyan);font-weight:700; }

        .cand-list { display:flex;flex-direction:column;gap:4px; }
        .cand-item {
            display:grid;grid-template-columns:20px 1fr auto;grid-template-rows:auto 3px;
            column-gap:6px;row-gap:3px;padding:5px 7px;border-radius:4px;
            background:#1a1e22;border:1px solid #252a2e;
            font-family:'JetBrains Mono',monospace;font-size:.74rem;cursor:pointer;
            transition:background .1s,border-color .1s;
        }
        .cand-item:hover, .cand-item.pv-active { background:#162030;border-color:var(--cyan); }
        .cand-badge { width:17px;height:17px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.58rem;font-weight:700;color:#000; }
        .cand-move { color:#e0e0e0;align-self:center; }
        .cand-wr   { color:var(--accent);font-size:.68rem;align-self:center;white-space:nowrap; }
        .cand-bar-bg { grid-column:1/-1;height:3px;background:#2a2e33;border-radius:2px;overflow:hidden; }
        .cand-bar  { height:100%;border-radius:2px;transition:width .3s; }

        #chart-canvas { width:100%;height:90px;display:block; }
        .no-data { font-family:'JetBrains Mono',monospace;font-size:.66rem;color:var(--dim);text-align:center;padding:8px 0; }
        .spinner {
            display:inline-block;width:9px;height:9px;
            border:2px solid rgba(0,229,255,.3);border-top-color:var(--cyan);
            border-radius:50%;animation:spin .7s linear infinite;vertical-align:middle;margin-right:4px;
        }
        @keyframes spin { to { transform:rotate(360deg); } }

        #sgf-drop-zone.drag-over {
            border-color: var(--cyan);
            background: rgba(0,229,255,0.05);
        }
        #sgf-drop-zone:hover {
            border-color: #444;
            background: rgba(255,255,255,0.02);
        }
    </style>
</head>
<body>
<header>
    <h1>⬡ Go Research Lab</h1>
    <span>v0.9 · game · research · pv-chain</span>
</header>

<div class="workspace">
    <div style="position:relative;flex-shrink:0;">
        <canvas id="canvas" width="600" height="600"></canvas>
        <div id="score-overlay-btns" style="display:none;position:absolute;pointer-events:auto;">
            <button onclick="confirmScore(true)"
                style="background:#1b4d1b;border:1px solid #2e7d32;color:#a5d6a7;font-family:'JetBrains Mono',monospace;font-size:.78rem;padding:7px 18px;border-radius:5px;cursor:pointer;">
                ✓ 동의 (대국 종료)
            </button>
            <button onclick="confirmScore(false)"
                style="background:#4a1515;border:1px solid #8b2020;color:#ff8a80;font-family:'JetBrains Mono',monospace;font-size:.78rem;padding:7px 18px;border-radius:5px;cursor:pointer;margin-left:8px;">
                ✗ 거부 (계속 대국)
            </button>
        </div>
    </div>

    <div class="sidebar">
        <div class="panel">
            <div class="ptitle">AI Server Settings (Colab)</div>
            <input type="text" id="api-url-input" placeholder="http://localhost:5000" 
                   style="width: 100%; background: #111; color: var(--cyan); border: 1px solid var(--border); padding: 5px; font-size: 0.65rem; border-radius: 4px; margin-bottom: 5px; outline: none; font-family: 'JetBrains Mono', monospace;">
            <button class="btn green" onclick="updateApiBase()" style="text-align: center; font-size: 0.7rem; padding: 4px;">연결하기</button>
        </div>

        <div class="panel" style="padding:6px;">
            <div style="display:flex;gap:4px;">
                <button class="btn" id="tab-game"     onclick="setAppMode('game')"     style="flex:1;text-align:center;padding:6px 0;font-size:.76rem;">🎮 대국</button>
                <button class="btn active" id="tab-research" onclick="setAppMode('research')" style="flex:1;text-align:center;padding:6px 0;font-size:.76rem;">🔬 연구</button>
            </div>
        </div>

        <div id="game-panel" style="display:none;flex-direction:column;gap:9px;">
            <div class="panel">
                <div class="ptitle">대국 설정</div>
                <div style="display:flex;flex-direction:column;gap:6px;">
                    <div class="ptitle" style="margin-bottom:3px;">내 돌 색</div>
                    <div style="display:flex;gap:4px;margin-bottom:2px;">
                        <div class="stone-opt black-active" id="game-pick-black" onclick="setPlayerColor(1)" style="flex:1;">● 흑</div>
                        <div class="stone-opt" id="game-pick-white" onclick="setPlayerColor(2)" style="flex:1;">○ 백</div>
                    </div>
                    <div class="ptitle" style="margin-bottom:3px;">AI 강도</div>
                    <div style="display:flex;align-items:center;gap:8px;">
                        <input type="range" id="level-slider" min="1" max="27" value="18"
                               oninput="setAiLevel(this.value)"
                               style="flex:1;accent-color:var(--cyan);">
                        <span id="level-label" style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--cyan);min-width:36px;text-align:right;">1급</span>
                    </div>
                    <div id="level-desc" style="font-family:'JetBrains Mono',monospace;font-size:.6rem;color:var(--dim);text-align:center;margin-bottom:2px;">visits:900</div>
                    <div class="ptitle" style="margin-bottom:3px;">덤 설정</div>
                    <div style="display:flex;align-items:center;gap:6px;">
                        <button class="btn" id="komi-minus" onclick="adjustKomi(-0.5)" style="width:28px;padding:4px 0;text-align:center;flex-shrink:0;">−</button>
                        <div style="flex:1;text-align:center;font-family:'JetBrains Mono',monospace;font-size:.82rem;color:var(--accent);" id="komi-display">6.5집</div>
                        <button class="btn" id="komi-plus"  onclick="adjustKomi(+0.5)" style="width:28px;padding:4px 0;text-align:center;flex-shrink:0;">+</button>
                        <button class="btn" onclick="resetKomi()" style="padding:4px 6px;font-size:.65rem;flex-shrink:0;">초기화</button>
                    </div>
                    <div id="komi-desc" style="font-family:'JetBrains Mono',monospace;font-size:.58rem;color:var(--dim);text-align:center;">백이 흑에게 6.5집 지급 (표준)</div>
                    <div class="ptitle" style="margin-bottom:3px;margin-top:2px;">접바둑</div>
                    <div style="display:flex;gap:3px;flex-wrap:wrap;">
                        <div class="stone-opt auto-active" id="hc-0" onclick="setHandicap(0)" style="flex:1;min-width:28px;font-size:.65rem;">없음</div>
                        <div class="stone-opt" id="hc-2" onclick="setHandicap(2)" style="flex:1;min-width:28px;font-size:.65rem;">2점</div>
                        <div class="stone-opt" id="hc-3" onclick="setHandicap(3)" style="flex:1;min-width:28px;font-size:.65rem;">3점</div>
                        <div class="stone-opt" id="hc-4" onclick="setHandicap(4)" style="flex:1;min-width:28px;font-size:.65rem;">4점</div>
                        <div class="stone-opt" id="hc-6" onclick="setHandicap(6)" style="flex:1;min-width:28px;font-size:.65rem;">6점</div>
                        <div class="stone-opt" id="hc-9" onclick="setHandicap(9)" style="flex:1;min-width:28px;font-size:.65rem;">9점</div>
                    </div>
                    <div id="hc-desc" style="font-family:'JetBrains Mono',monospace;font-size:.58rem;color:var(--dim);text-align:center;">접바둑 없음</div>
                    <div class="ptitle" style="margin-bottom:3px;margin-top:2px;">무르기</div>
                    <div style="display:flex;gap:4px;">
                        <div class="stone-opt" id="undo-0" onclick="setUndoLimit(0)" style="flex:1;font-size:.65rem;">없음</div>
                        <div class="stone-opt auto-active" id="undo-3" onclick="setUndoLimit(3)" style="flex:1;font-size:.65rem;">3회</div>
                        <div class="stone-opt" id="undo-inf" onclick="setUndoLimit(-1)" style="flex:1;font-size:.65rem;">무제한</div>
                    </div>
                    <div id="undo-count-wrap" style="display:none;font-family:'JetBrains Mono',monospace;font-size:.62rem;color:var(--accent);text-align:center;">남은 무르기: 3회</div>
                    <button class="btn green" id="game-start-btn" onclick="startGame()" style="margin-top:2px;">▶ 대국 시작</button>
                </div>
            </div>
            <div class="panel">
                <div class="ptitle">대국 현황</div>
                <div id="game-status" style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--cyan);min-height:1.4em;text-align:center;">대국 전</div>
                <div id="game-btns" style="display:none;flex-direction:column;gap:5px;margin-top:8px;">
                    <div style="display:flex;gap:4px;">
                        <button class="btn" id="game-hint-btn" onclick="requestHint()" style="flex:1;font-size:.74rem;">💡 힌트</button>
                        <button class="btn" id="game-undo-btn" onclick="undoMove()" style="flex:1;font-size:.74rem;">↩ 무르기</button>
                    </div>
                    <div style="display:flex;gap:4px;">
                        <button class="btn" id="game-pass-btn" onclick="passMove()" style="flex:1;font-size:.74rem;">◻ 패스</button>
                        <button class="btn danger" id="game-resign-btn" onclick="resignGame()" style="flex:1;font-size:.74rem;">⚑ 기권</button>
                    </div>
                    <button class="btn" id="game-score-btn" onclick="requestScore()" style="font-size:.74rem;border-color:#0288d1;color:#4fc3f7;">🧮 계가 신청</button>
                    <button class="btn" id="game-chart-btn" onclick="toggleGameChart()" style="font-size:.74rem;">📈 승률그래프: OFF</button>
                </div>
                <div id="game-wr-wrap" style="display:none;margin-top:8px;">
                    <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                        <span id="game-wr-black" style="font-family:'JetBrains Mono',monospace;font-size:.78rem;color:var(--win-b);font-weight:700;">50%</span>
                        <span id="game-score-label" style="font-family:'JetBrains Mono',monospace;font-size:.64rem;color:#aaa;">-</span>
                        <span id="game-wr-white" style="font-family:'JetBrains Mono',monospace;font-size:.78rem;color:var(--win-w);font-weight:700;">50%</span>
                    </div>
                    <div style="width:100%;height:10px;border-radius:5px;overflow:hidden;display:flex;">
                        <div id="game-bar-black" style="height:100%;background:var(--win-b);transition:width .4s;width:50%;"></div>
                        <div id="game-bar-white" style="height:100%;background:var(--win-w);transition:width .4s;width:50%;"></div>
                    </div>
                </div>
                <div id="game-chart-wrap" style="display:none;margin-top:6px;">
                    <canvas id="game-chart-canvas" style="width:100%;height:80px;display:block;cursor:grab;"></canvas>
                </div>
                <button class="btn purple" id="game-review-btn" onclick="goToReview()" style="display:none;margin-top:8px;">🔬 복기하기</button>
                <button class="btn green"  id="game-start-btn2" onclick="startGame()" style="display:none;margin-top:4px;font-size:.76rem;">▶ 다시 대국</button>
                <button class="btn" id="ownership-btn" onclick="toggleOwnership()" style="margin-top:8px;display:none;">🗺 형세판단: OFF</button>
                <div id="ownership-score" style="display:none;margin-top:8px;background:#151a1e;border:1px solid #2e3338;border-radius:6px;padding:8px 10px;">
                    <div style="font-family:'JetBrains Mono',monospace;font-size:.62rem;color:var(--dim);margin-bottom:6px;">형세판단 (사석 포함)</div>
                    <div style="display:flex;justify-content:space-between;align-items:center;gap:6px;">
                        <div style="flex:1;text-align:center;">
                            <div style="font-family:'JetBrains Mono',monospace;font-size:.64rem;color:#888;margin-bottom:2px;">● 흑</div>
                            <div id="score-black" style="font-family:'JetBrains Mono',monospace;font-size:1.1rem;color:var(--win-b);font-weight:700;">-</div>
                        </div>
                        <div id="score-result" style="font-family:'JetBrains Mono',monospace;font-size:.68rem;color:var(--accent);text-align:center;min-width:60px;">-</div>
                        <div style="flex:1;text-align:center;">
                            <div style="font-family:'JetBrains Mono',monospace;font-size:.64rem;color:#888;margin-bottom:2px;">○ 백</div>
                            <div id="score-white" style="font-family:'JetBrains Mono',monospace;font-size:1.1rem;color:var(--win-w);font-weight:700;">-</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div id="research-panel" style="display:flex;flex-direction:column;gap:9px;">
        <div class="panel">
            <div class="ptitle">수순</div>
            <div class="turn-row">
                <div id="turn-stone"></div>
                <span id="turn-text">흑 (Black)</span>
                <div class="nav-btns">
                    <button class="nav-btn" id="nav-first" onclick="navFirst()" title="처음으로">⏮</button>
                    <button class="nav-btn" id="nav-prev"  onclick="navPrev()"  title="한 수 뒤로">◀</button>
                    <button class="nav-btn" id="nav-next"  onclick="navNext()"  title="한 수 앞으로">▶</button>
                    <button class="nav-btn" id="nav-last"  onclick="navLast()"  title="마지막으로">⏭</button>
                </div>
            </div>
            <div id="move-counter">0수</div>
        </div>

        <div class="panel" id="sgf-load-panel">
            <div class="ptitle">기보 불러오기</div>
            <div id="sgf-drop-zone"
                 ondragover="event.preventDefault();this.classList.add('drag-over')"
                 ondragleave="this.classList.remove('drag-over')"
                 ondrop="handleSGFDrop(event)"
                 onclick="document.getElementById('sgf-file-input').click()"
                 style="border:2px dashed var(--border);border-radius:6px;padding:14px 8px;text-align:center;cursor:pointer;transition:border-color .15s,background .15s;">
                <div style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--dim);">📂 SGF / GIB 파일 드롭</div>
                <div style="font-family:'JetBrains Mono',monospace;font-size:.6rem;color:#444;margin-top:3px;">또는 클릭해서 선택</div>
            </div>
            <input type="file" id="sgf-file-input" accept=".sgf,.gib" style="display:none" onchange="handleSGFFile(this)">
            <div id="sgf-meta" style="display:none;margin-top:8px;background:#151a1e;border:1px solid #2e3338;border-radius:6px;padding:8px 10px;font-family:'JetBrains Mono',monospace;font-size:.66rem;">
                <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                    <span style="color:#888;">● 흑</span>
                    <span id="meta-black" style="color:#ddd;text-align:right;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">-</span>
                </div>
                <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                    <span style="color:#888;">○ 백</span>
                    <span id="meta-white" style="color:#ddd;text-align:right;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">-</span>
                </div>
                <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                    <span style="color:#888;">결과</span>
                    <span id="meta-result" style="color:var(--accent);">-</span>
                </div>
                <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
                    <span style="color:#888;">덤</span>
                    <span id="meta-komi" style="color:#ddd;">-</span>
                </div>
                <div style="display:flex;justify-content:space-between;">
                    <span style="color:#888;">날짜</span>
                    <span id="meta-date" style="color:#ddd;">-</span>
                </div>
            </div>
            <div id="sgf-nav-wrap" style="display:none;margin-top:8px;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;">
                    <span style="font-family:'JetBrains Mono',monospace;font-size:.6rem;color:var(--dim);">불러온 기보</span>
                    <span id="sgf-move-label" style="font-family:'JetBrains Mono',monospace;font-size:.6rem;color:var(--cyan);">0 / 0수</span>
                </div>
                <input type="range" id="sgf-slider" min="0" value="0"
                       oninput="seekSGF(parseInt(this.value))"
                       style="width:100%;accent-color:var(--cyan);">
                <div id="sgf-comment" style="display:none;margin-top:6px;background:#1a1f25;border-left:2px solid var(--cyan);padding:5px 8px;font-family:'JetBrains Mono',monospace;font-size:.62rem;color:#aaa;line-height:1.5;max-height:80px;overflow-y:auto;"></div>
            </div>
        </div>

        <div class="panel">
            <div class="ptitle">조작</div>
            <div class="ptitle" style="margin-bottom:5px;">돌 놓기 모드</div>
            <div class="stone-picker" style="margin-bottom:8px;">
                <div class="stone-opt" id="pick-black" onclick="setStoneMode('black')">● 흑</div>
                <div class="stone-opt auto-active" id="pick-auto" onclick="setStoneMode('auto')">⇄ 교대</div>
                <div class="stone-opt" id="pick-white" onclick="setStoneMode('white')">○ 백</div>
            </div>
            <div style="display:flex;flex-direction:column;gap:5px;">
                <button class="btn" id="toggle-num" onclick="toggleNumbers()">수순 표시: OFF</button>
                <button class="btn green"  id="research-btn" onclick="toggleResearchMode()">🔬 놓아보기 시작</button>
                <button class="btn" id="branch-reset-btn" onclick="resetToBranch()" style="display:none;background:#1a2a1a;border-color:#2e7d32;color:#a5d6a7;font-size:.75rem;">↩ 연구 전으로 복귀</button>
                <button class="btn purple" id="region-btn"   onclick="toggleRegionMode()">⬚ 부분 연구 모드: OFF</button>
                <button class="btn" id="region-reset-btn" onclick="resetRegion()" style="display:none;font-size:.72rem;color:#ce93d8;border-color:#7b1fa2;">↺ 영역 재설정</button>
                <button class="btn" onclick="saveSGF()">💾 SGF 저장</button>
                <button class="btn danger" onclick="resetBoard()">✕ 초기화</button>
            </div>
        </div>

        <div class="panel">
            <div class="ptitle">AI 분석 (KataGo)</div>
            <div style="display:flex;flex-direction:column;gap:5px;margin-bottom:8px;">
                <button class="btn primary" id="manual-btn" onclick="requestAI()">▶ 분석 요청</button>
                <button class="btn" id="realtime-btn" onclick="toggleRealtime()">⚡ 실시간 AI: OFF</button>
                <div>
                    <div class="ptitle" style="margin-bottom:4px;">분석 속도</div>
                    <div class="speed-group">
                        <div class="speed-btn" id="speed-fast"   onclick="setSpeed('fast')">⚡ 빠름</div>
                        <div class="speed-btn active" id="speed-normal" onclick="setSpeed('normal')">▶ 보통</div>
                        <div class="speed-btn" id="speed-deep"   onclick="setSpeed('deep')">🔍 정밀</div>
                    </div>
                </div>
            </div>
            <div id="ai-status"></div>
            <div class="ptitle" style="margin-top:9px;">
                후보 수 <span style="color:#444;font-size:.54rem;font-family:'JetBrains Mono',monospace;">— 우클릭 → pv 수순</span>
            </div>
            <div class="cand-list" id="cand-list">
                <div class="no-data">분석 결과 없음</div>
            </div>
            <button class="btn" id="ownership-btn-research" onclick="toggleOwnership()" style="margin-top:8px;display:none;">🗺 형세판단: OFF</button>
        </div>

        <div class="panel">
            <div class="ptitle">승률 흐름</div>
            <div id="wr-bar-wrap" style="display:none;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;">
                    <span id="wr-black-pct" style="font-family:'JetBrains Mono',monospace;font-size:.78rem;color:var(--win-b);font-weight:700;">50%</span>
                    <span id="wr-score-label" style="font-family:'JetBrains Mono',monospace;font-size:.64rem;color:#aaa;">집차이: -</span>
                    <span id="wr-white-pct" style="font-family:'JetBrains Mono',monospace;font-size:.78rem;color:var(--win-w);font-weight:700;">50%</span>
                </div>
                <div style="width:100%;height:10px;border-radius:5px;overflow:hidden;display:flex;">
                    <div id="wr-bar-black" style="height:100%;background:var(--win-b);transition:width .4s;width:50%;"></div>
                    <div id="wr-bar-white" style="height:100%;background:var(--win-w);transition:width .4s;width:50%;"></div>
                </div>
            </div>
            <canvas id="chart-canvas" style="margin-top:8px;cursor:grab;"></canvas>
            <div id="chart-ph" class="no-data">AI 분석 후 업데이트</div>
            <div id="chart-hint" style="display:none;font-family:'JetBrains Mono',monospace;font-size:.55rem;color:var(--dim);text-align:center;margin-top:2px;">← 드래그로 탐색</div>
        </div>

<div id="score-modal" style="
    display:none;position:fixed;inset:0;z-index:999;
    background:rgba(0,0,0,0.65);
    align-items:center;justify-content:center;">
    <div style="
        background:#1c1f23;border:1px solid #2e3338;border-radius:12px;
        padding:28px 32px;min-width:300px;max-width:360px;
        font-family:'JetBrains Mono',monospace;box-shadow:0 20px 60px rgba(0,0,0,0.6);">
        <div style="text-align:center;font-size:1rem;color:#f0c040;font-weight:700;margin-bottom:16px;letter-spacing:.06em;">
            🧮 계가 결과
        </div>
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
            <span style="font-size:.78rem;color:#64dd17;">● 흑</span>
            <span id="modal-black" style="font-size:1.1rem;color:#64dd17;font-weight:700;">-</span>
        </div>
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:4px;">
            <span style="font-size:.78rem;color:#ff6e40;">○ 백</span>
            <span id="modal-white" style="font-size:1.1rem;color:#ff6e40;font-weight:700;">-</span>
        </div>
        <div style="font-size:.6rem;color:#555;text-align:right;margin-bottom:14px;" id="modal-komi-note">덤 6.5집 포함</div>
        <div style="height:1px;background:#2e3338;margin-bottom:14px;"></div>
        <div id="modal-result" style="text-align:center;font-size:1.3rem;font-weight:700;margin-bottom:6px;">-</div>
        <div id="modal-raw" style="text-align:center;font-size:.62rem;color:#555;margin-bottom:6px;">-</div>
        <div style="text-align:center;font-size:.7rem;color:#888;margin-bottom:18px;">계가 결과에 동의하시겠습니까?</div>
        <div style="display:flex;gap:8px;">
            <button onclick="confirmScoreModal(false)" class="btn danger" style="flex:1;text-align:center;">✗ 거부 (계속)</button>
            <button onclick="confirmScoreModal(true)"  class="btn green"  style="flex:1;text-align:center;">✓ 동의 (종료)</button>
        </div>
    </div>
</div>

</div>

<script>
/* ================================================================
   서버 설정 및 상태
================================================================ */
let apiBase = 'http://localhost:5000';

function updateApiBase() {
    const val = document.getElementById('api-url-input').value;
    if(val) {
        apiBase = val.replace(/\/$/, ""); 
        alert(`서버 주소가 설정되었습니다: ${apiBase}`);
    }
}

const SIZE      = 19;
const PAD       = 34;
const GTP_COLS  = "abcdefghjklmnopqrst";
const COL_LABELS= "ABCDEFGHJKLMNOPQRST";
const COLOR_TOP  = '#00e5ff';
const COLOR_REST = '#ffca28';
const SPEED_MAP  = { fast:200, normal:400, deep:800 };

const DPR = window.devicePixelRatio || 1;
const CANVAS_CSS = 600;
const CANVAS_PX  = CANVAS_CSS * DPR;
const CELL = (CANVAS_CSS - PAD * 2) / (SIZE - 1);

const canvas = document.getElementById('canvas');
const ctx    = canvas.getContext('2d');
canvas.width = CANVAS_PX; canvas.height = CANVAS_PX;
canvas.style.width  = CANVAS_CSS + 'px';
canvas.style.height = CANVAS_CSS + 'px';
ctx.scale(DPR, DPR);

let board        = Array.from({length:SIZE},()=>Array(SIZE).fill(0));
let boardHistory = [];
let moveHistory  = [];
let futureStack  = [];
let turn         = 1;
let stoneMode    = 'auto';
let showNumbers   = false;
let isResearching = false;
let researchStart = 0;
let candidates    = [];
let wrHistory     = [];
let koPoint       = null;
let sgfMoves    = [];
let sgfLoaded   = false;
let sgfCurrent  = 0;
let appMode      = 'research';
let playerColor  = 1;
let aiLevel      = 18;
let gameKomi     = 6.5;
let gameHandicap = 0;
let gameActive   = false;
let aiThinking   = false;
let passCount    = 0;
let undoLimit    = 3;
let undoRemain   = 3;
let showGameChart = false;
let scoreResult   = null;
let ownershipData = null;
let showOwnership = false;
let pvChain          = [];
let pvCandidates     = [];
let pvActive         = false;
let nextResearchNum  = 1;
let branchSnapshot = null;
let realtimeOn      = false;
let realtimeTimer   = null;
let pendingAnalysis = false;
let isAnalyzing     = false;
let lzVisits        = 400;
let regionMode  = false;
let regionDrag  = false;
let regionStart = null;
let regionEnd   = null;
let regionRect  = null;
const CHART_WINDOW = 15;
let chartOffset    = 0;
let chartDrag      = false;
let chartDragStartX= 0;
let chartDragStartOffset = 0;

/* ================================================================
   좌표 및 유틸
================================================================ */
function gtpToRC(gtp) {
    gtp = gtp.toLowerCase();
    return { c: GTP_COLS.indexOf(gtp[0]), r: SIZE - parseInt(gtp.substring(1)) };
}
function rcToGTP(r,c){ return GTP_COLS[c].toUpperCase()+(SIZE-r); }
function canvasToRC(ex, ey) {
    const rect = canvas.getBoundingClientRect();
    const lx = (ex - rect.left) * (CANVAS_CSS / rect.width);
    const ly = (ey - rect.top)  * (CANVAS_CSS / rect.height);
    return { r: Math.round((ly - PAD) / CELL), c: Math.round((lx - PAD) / CELL) };
}
function clampRC(r,c){ return {r:Math.max(0,Math.min(SIZE-1,r)), c:Math.max(0,Math.min(SIZE-1,c))}; }
function normalizeRegion(a,b){
    return {r1:Math.min(a.r,b.r),c1:Math.min(a.c,b.c),r2:Math.max(a.r,b.r),c2:Math.max(a.c,b.c)};
}

/* ================================================================
   그리기 로직
================================================================ */
function draw() {
    const C = CANVAS_CSS;
    ctx.fillStyle = '#c8922a'; ctx.fillRect(0, 0, C, C);
    for(let i=0;i<5;i++){
        ctx.beginPath(); ctx.moveTo(0, 80+i*110); ctx.lineTo(C, 65+i*110);
        ctx.strokeStyle='rgba(0,0,0,0.03)'; ctx.lineWidth=10; ctx.stroke();
    }
    ctx.strokeStyle='rgba(80,50,10,0.4)'; ctx.lineWidth=1;
    ctx.strokeRect(PAD, PAD, (SIZE-1)*CELL, (SIZE-1)*CELL);
    const labelSize = Math.round(CELL*0.3);
    ctx.font = `${labelSize}px 'JetBrains Mono',monospace`;
    ctx.fillStyle = 'rgba(60,30,0,0.65)'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for(let i=0;i<SIZE;i++){
        ctx.fillText(COL_LABELS[i], PAD+i*CELL, PAD-13);
        ctx.fillText(COL_LABELS[i], PAD+i*CELL, C-PAD+13);
        ctx.fillText(String(SIZE-i), PAD-13, PAD+i*CELL);
        ctx.fillText(String(SIZE-i), C-PAD+13, PAD+i*CELL);
    }
    ctx.strokeStyle='#5a3a10'; ctx.lineWidth=0.8;
    for(let i=0;i<SIZE;i++){
        ctx.beginPath(); ctx.moveTo(PAD, PAD+i*CELL); ctx.lineTo(C-PAD, PAD+i*CELL); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(PAD+i*CELL, PAD); ctx.lineTo(PAD+i*CELL, C-PAD); ctx.stroke();
    }
    [3,9,15].forEach(r=>[3,9,15].forEach(c=>{
        ctx.beginPath(); ctx.arc(PAD+c*CELL,PAD+r*CELL,3.5,0,Math.PI*2);
        ctx.fillStyle='#5a3a10'; ctx.fill();
    }));
    const activeRegion = regionRect || (regionMode&&regionStart&&regionEnd ? normalizeRegion(regionStart,regionEnd) : null);
    if(activeRegion){
        const x1=PAD+activeRegion.c1*CELL-CELL/2, y1=PAD+activeRegion.r1*CELL-CELL/2;
        const x2=PAD+activeRegion.c2*CELL+CELL/2, y2=PAD+activeRegion.r2*CELL+CELL/2;
        ctx.fillStyle='rgba(123,31,162,0.07)'; ctx.fillRect(x1,y1,x2-x1,y2-y1);
        ctx.strokeStyle='#9c27b0'; ctx.lineWidth=2; ctx.setLineDash([6,3]);
        ctx.strokeRect(x1,y1,x2-x1,y2-y1); ctx.setLineDash([]);
    }
    const displayCands = pvActive ? pvCandidates : candidates;
    if(displayCands.length>0){
        if(regionRect && !pvActive){
            const inR  = displayCands.filter(c=>isInRegion(c.move)).slice(0,3);
            const outR = displayCands.filter(c=>!isInRegion(c.move)).slice(0,3);
            inR.forEach( (cand,i)=>drawSpot(cand,i,'in',  false));
            outR.forEach((cand,i)=>drawSpot(cand,i,'out', false));
        } else {
            displayCands.slice(0,3).forEach((cand,i)=>drawSpot(cand,i,'normal',false));
        }
    }
    if(showOwnership && ownershipData && ownershipData.length === SIZE*SIZE){
        for(let r=0;r<SIZE;r++) for(let c=0;c<SIZE;c++){
            const val = ownershipData[r*SIZE+c];
            if(Math.abs(val) < 0.05) continue;
            const x = PAD+c*CELL, y = PAD+r*CELL;
            const alpha = Math.min(Math.abs(val) * 0.7, 0.65);
            const size  = CELL * 0.82;
            ctx.fillStyle = val > 0 ? `rgba(0,0,0,${alpha})` : `rgba(255,255,255,${alpha})`;
            ctx.fillRect(x - size/2, y - size/2, size, size);
            ctx.strokeStyle = val > 0 ? `rgba(0,0,0,0.8)` : `rgba(180,180,180,0.8)`;
            ctx.lineWidth = 0.5; ctx.strokeRect(x - size/2, y - size/2, size, size);
        }
    }
    for(let r=0;r<SIZE;r++) for(let c=0;c<SIZE;c++){
        if(!board[r][c]) continue;
        const x=PAD+c*CELL, y=PAD+r*CELL;
        const isBlack=board[r][c]===1;
        const isLast=moveHistory.length>0&&moveHistory[moveHistory.length-1].r===r&&moveHistory[moveHistory.length-1].c===c;
        ctx.shadowColor='rgba(0,0,0,0.4)'; ctx.shadowBlur=6; ctx.shadowOffsetX=2; ctx.shadowOffsetY=2;
        const g=ctx.createRadialGradient(x-CELL*.15,y-CELL*.15,CELL*.05,x,y,CELL*.43);
        if(isBlack){g.addColorStop(0,'#555');g.addColorStop(1,'#111');}
        else{g.addColorStop(0,'#fff');g.addColorStop(1,'#ccc');}
        ctx.beginPath(); ctx.arc(x,y,CELL*.44,0,Math.PI*2); ctx.fillStyle=g; ctx.fill();
        ctx.shadowColor='transparent'; ctx.shadowBlur=0; ctx.shadowOffsetX=0; ctx.shadowOffsetY=0;
        if(!isBlack){ctx.strokeStyle='#aaa';ctx.lineWidth=0.5;ctx.stroke();}
        if(isLast&&!showNumbers&&!isResearching&&!pvActive){
            ctx.beginPath(); ctx.arc(x,y,5,0,Math.PI*2); ctx.fillStyle='#ff1744'; ctx.fill();
        }
        const mIdx=moveHistory.findLastIndex(m=>m.r===r&&m.c===c);
        const showN=showNumbers||(isResearching&&mIdx>=researchStart);
        if(showN&&mIdx>=0){
            const m=moveHistory[mIdx];
            const num=showNumbers ? mIdx+1 : (m.num ?? mIdx-researchStart+1);
            ctx.font=`bold ${CELL*.34}px 'JetBrains Mono',monospace`;
            ctx.textAlign='center'; ctx.textBaseline='middle';
            ctx.fillStyle=isLast?'#ffeb3b':(isBlack?'#ddd':'#333');
            ctx.fillText(num,x,y);
        }
    }
    if(pvActive && pvChain.length>0) drawPVChain();
    if(appMode === 'game' && aiThinking){
        ctx.fillStyle = 'rgba(0,0,0,0.18)'; ctx.fillRect(0, 0, C, C);
        ctx.font = `bold 18px 'JetBrains Mono',monospace`;
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillStyle = '#00e5ff'; ctx.fillText('AI 생각 중...', C/2, C/2);
    }
    updateNavButtons();
}

function drawSpot(cand, rank, mode='normal', highlighted=false) {
    const {r,c}=gtpToRC(cand.move);
    if(r<0||r>=SIZE||c<0||c>=SIZE) return;
    const x=PAD+c*CELL, y=PAD+r*CELL;
    let color;
    if(mode==='in')       color = rank===0?'#00e5ff':'#4dd0e1';
    else if(mode==='out') color = rank===0?'#ff9800':'#ffcc80';
    else                  color = rank===0?COLOR_TOP:COLOR_REST;
    const radius=CELL*0.42;
    const alpha=highlighted?0.97:(rank===0?0.88:0.70);
    ctx.beginPath(); ctx.arc(x,y,radius,0,Math.PI*2);
    ctx.fillStyle=hexA(color,alpha); ctx.fill();
    ctx.strokeStyle=color; ctx.lineWidth=highlighted?3:(rank===0?2.5:1.5);
    if(rank===0&&!highlighted){ctx.setLineDash([5,3]); ctx.stroke(); ctx.setLineDash([]);}
    else ctx.stroke();
    if(highlighted){ ctx.strokeStyle='#fff'; ctx.lineWidth=1.5; ctx.stroke(); }
    ctx.font=`bold 12px 'JetBrains Mono',monospace`;
    ctx.textAlign='center'; ctx.textBaseline='middle';
    ctx.fillStyle='#000'; ctx.fillText(cand.winrate.toFixed(0)+'%',x,y);
}

/* ================================================================
   PV 시스템 및 데이터 로직
================================================================ */
function extendPVChain(cand) {
    const startNum  = nextResearchNum + pvChain.length;
    const startTurn = cand._turn != null ? cand._turn : turn;
    pvChain.push({ move: cand.move, isBlack: startTurn===1, num: startNum });
    (cand.pv||[]).forEach((mv, step) => {
        const isBlk = step%2===0 ? (startTurn===2) : (startTurn===1);
        pvChain.push({ move: mv, isBlack: isBlk, num: startNum + step + 1 });
    });
}
function drawPVChain() {
    pvChain.forEach(({move, isBlack, num}) => {
        const {r,c}=gtpToRC(move);
        if(r<0||r>=SIZE||c<0||c>=SIZE) return;
        const x=PAD+c*CELL, y=PAD+r*CELL;
        const radius = CELL*0.41;
        ctx.shadowColor='rgba(0,0,0,0.4)'; ctx.shadowBlur=4; ctx.shadowOffsetX=1; ctx.shadowOffsetY=1;
        const g=ctx.createRadialGradient(x-CELL*.12,y-CELL*.12,CELL*.03,x,y,radius);
        if(isBlack){g.addColorStop(0,'#555');g.addColorStop(1,'#111');}
        else{g.addColorStop(0,'#fff');g.addColorStop(1,'#ccc');}
        ctx.beginPath(); ctx.arc(x,y,radius,0,Math.PI*2); ctx.fillStyle=g; ctx.fill();
        ctx.shadowColor='transparent'; ctx.shadowBlur=0; ctx.shadowOffsetX=0; ctx.shadowOffsetY=0;
        if(!isBlack){ctx.strokeStyle='#aaa';ctx.lineWidth=0.5;ctx.stroke();}
        ctx.font=`bold ${num<10?12:10}px 'JetBrains Mono',monospace`;
        ctx.textAlign='center'; ctx.textBaseline='middle';
        ctx.fillStyle = isBlack?'#fff':'#000'; ctx.fillText(num, x, y);
    });
}
function startPV(cand) {
    if(isResearching && pvChain.length>0){
        if(!branchSnapshot){
            branchSnapshot={ board: JSON.parse(JSON.stringify(board)), moveHistory: JSON.parse(JSON.stringify(moveHistory)), turn, koPoint };
            document.getElementById('branch-reset-btn').style.display='block';
        }
        pvChain.forEach(({move, isBlack, num})=>{
            const {r,c}=gtpToRC(move);
            if(r<0||r>=SIZE||c<0||c>=SIZE||board[r][c]!==0) return;
            const color=isBlack?1:2;
            boardHistory.push({board: JSON.parse(JSON.stringify(board)), move:{color,r,c}, koPoint});
            moveHistory.push({color, r, c, num});
            board[r][c]=color;
        });
        const last=pvChain[pvChain.length-1];
        turn=last.isBlack?2:1;
        futureStack=[]; nextResearchNum = last.num + 1; updateTurnUI();
    }
    pvChain=[]; extendPVChain(cand); pvActive=true; updatePVCandidates();
}
function extendPV(cand) { extendPVChain(cand); updatePVCandidates(); }
function clearPV(resetNum=true) {
    pvChain = []; pvCandidates = []; pvActive = false;
    if(resetNum) nextResearchNum = 1;
}
function clearPVKeepOffset() { clearPV(false); }
function updatePVCandidates() {
    if(pvChain.length===0) return;
    const lastEntry = pvChain[pvChain.length-1];
    const nextTurn  = lastEntry.isBlack ? 2 : 1;
    const gtpMoves = [
        ...moveHistory.map(m=>[m.color===1?'B':'W', rcToGTP(m.r,m.c)]),
        ...pvChain.map(e=>[e.isBlack?'B':'W', e.move])
    ];
    requestPVAnalysis(gtpMoves, nextTurn);
}

// ★ fetch 경로 치환
async function requestPVAnalysis(gtpMoves, nextTurn) {
    const statusEl = document.getElementById('ai-status');
    statusEl.innerHTML='<span class="spinner"></span>pv 분석 중...';
    try {
        const res=await fetch(`${apiBase}/analyze`,{
            method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({moves: gtpMoves, lz_visits: lzVisits, region_mode: false})
        });
        const data=await res.json();
        const cands=(data.candidates||[]).slice(0,3).map(c=>({...c, _turn: nextTurn}));
        pvCandidates = cands; statusEl.textContent=`✅ pv+${pvChain.length}수 분석완료`; renderCandList(); draw();
    } catch(e){ statusEl.textContent='⚠ pv 분석 오류'; }
}

function hexA(hex,a){
    const r=parseInt(hex.slice(1,3),16),g=parseInt(hex.slice(3,5),16),b=parseInt(hex.slice(5,7),16);
    return `rgba(${r},${g},${b},${a})`;
}

/* ================================================================
   바둑 엔진
================================================================ */
function getGroup(r, c, b) {
    const color = b[r][c]; if(!color) return new Set();
    const group = new Set(); const stack = [[r,c]];
    while(stack.length){
        const [cr,cc] = stack.pop(); const key = cr*SIZE+cc;
        if(group.has(key)) continue;
        group.add(key);
        [[cr-1,cc],[cr+1,cc],[cr,cc-1],[cr,cc+1]].forEach(([nr,nc])=>{
            if(nr>=0&&nr<SIZE&&nc>=0&&nc<SIZE&&b[nr][nc]===color&&!group.has(nr*SIZE+nc)) stack.push([nr,nc]);
        });
    }
    return group;
}
function getLiberties(group, b) {
    const liberties = new Set();
    group.forEach(key=>{
        const r=Math.floor(key/SIZE), c=key%SIZE;
        [[r-1,c],[r+1,c],[r,c-1],[r,c+1]].forEach(([nr,nc])=>{
            if(nr>=0&&nr<SIZE&&nc>=0&&nc<SIZE&&b[nr][nc]===0) liberties.add(nr*SIZE+nc);
        });
    });
    return liberties;
}
function tryPlace(r, c, color) {
    if(board[r][c]!==0) return false;
    const b = board.map(row=>[...row]); b[r][c] = color;
    const opp = color===1?2:1; let captured = [];
    [[r-1,c],[r+1,c],[r,c-1],[r,c+1]].forEach(([nr,nc])=>{
        if(nr<0||nr>=SIZE||nc<0||nc>=SIZE) return;
        if(b[nr][nc]!==opp) return;
        const g = getGroup(nr,nc,b);
        if(getLiberties(g,b).size===0){
            g.forEach(key=>{
                const gr=Math.floor(key/SIZE), gc=key%SIZE;
                captured.push([gr,gc]); b[gr][gc]=0;
            });
        }
    });
    const myGroup = getGroup(r,c,b);
    if(getLiberties(myGroup,b).size===0) return false;
    let newKoPoint = null;
    if(captured.length===1){
        const [kr,kc]=captured[0]; if(myGroup.size===1) newKoPoint={r:kr,c:kc};
    }
    if(koPoint && koPoint.r===r && koPoint.c===c) return false;
    return { newBoard: b, captured, koPoint: newKoPoint };
}

/* ================================================================
   마우스 및 입력 제어
================================================================ */
canvas.addEventListener('click', e => {
    const {r,c}=canvasToRC(e.clientX,e.clientY);
    if(r<0||r>=SIZE||c<0||c>=SIZE) return;
    if(appMode === 'game'){
        if(!gameActive || aiThinking) return;
        if(turn !== playerColor) return;
        if(board[r][c] !== 0) return;
        if(pvActive) clearPV();
        candidates = [];
        const result = tryPlace(r, c, turn);
        if(!result) return;
        passCount = 0;
        boardHistory.push({board:JSON.parse(JSON.stringify(board)),move:{color:turn,r,c},koPoint});
        moveHistory.push({color:turn, r, c});
        board   = result.newBoard; koPoint = result.koPoint; turn    = turn===1?2:1;
        updateTurnUI(); draw(); setGameStatus('AI 생각 중...'); requestAIMove();
        return;
    }
    if(regionMode){ if(!regionRect) return; }
    if(board[r][c]!==0) return;
    if(pvActive && pvChain.length>0){
        if(isResearching){
            if(!branchSnapshot){
                branchSnapshot={board:JSON.parse(JSON.stringify(board)),moveHistory:JSON.parse(JSON.stringify(moveHistory)),turn,koPoint};
                document.getElementById('branch-reset-btn').style.display='block';
            }
            const lastPV = pvChain[pvChain.length-1];
            pvChain.forEach(({move,isBlack,num})=>{
                const {r:pr,c:pc}=gtpToRC(move);
                if(pr<0||pr>=SIZE||pc<0||pc>=SIZE||board[pr][pc]!==0) return;
                const col=isBlack?1:2;
                boardHistory.push({board:JSON.parse(JSON.stringify(board)),move:{color:col,r:pr,c:pc},koPoint});
                moveHistory.push({color:col, r:pr, c:pc, num}); board[pr][pc]=col;
            });
            turn=lastPV.isBlack?2:1; nextResearchNum = lastPV.num + 1;
            futureStack=[]; pvChain=[]; pvCandidates=[]; pvActive=false; updateTurnUI();
            if(board[r][c]!==0){ draw(); if(realtimeOn)triggerRealtime(); return; }
        } else clearPV();
    }
    const color=stoneMode==='black'?1:stoneMode==='white'?2:turn;
    const result=tryPlace(r,c,color);
    if(!result) return;
    if(!branchSnapshot && isResearching){
        branchSnapshot={board:JSON.parse(JSON.stringify(board)),moveHistory:JSON.parse(JSON.stringify(moveHistory)),turn,koPoint};
        document.getElementById('branch-reset-btn').style.display='block';
    }
    boardHistory.push({board:JSON.parse(JSON.stringify(board)),move:{color,r,c},koPoint});
    futureStack=[];
    if(isResearching){ moveHistory.push({color, r, c, num: nextResearchNum}); nextResearchNum++; }
    else moveHistory.push({color, r, c});
    board   = result.newBoard; koPoint = result.koPoint;
    if(stoneMode==='auto') turn=turn===1?2:1;
    updateTurnUI(); draw();
    if(realtimeOn) triggerRealtime();
});

canvas.addEventListener('mousedown', e => {
    if(e.button!==0) return;
    if(!regionMode||regionRect) return;
    const {r,c}=canvasToRC(e.clientX,e.clientY);
    if(r<0||r>=SIZE||c<0||c>=SIZE) return;
    regionDrag=true; regionStart={r,c}; regionEnd={r,c};
    canvas.classList.add('region-drag'); draw();
});
canvas.addEventListener('contextmenu', e => {
    e.preventDefault(); e.stopPropagation();
    const {r,c}=canvasToRC(e.clientX,e.clientY);
    const searchList = pvActive ? pvCandidates : candidates;
    let closest=null, minDist=Infinity;
    searchList.forEach((cand,idx)=>{
        const {r:cr,c:cc}=gtpToRC(cand.move);
        const dist=Math.sqrt((r-cr)**2+(c-cc)**2);
        if(dist<2.0&&dist<minDist){ minDist=dist; closest=cand; }
    });
    if(closest===null){
        branchSnapshot ? clearPVKeepOffset() : clearPV();
        candidates = candidates.map(c=>c); renderCandList(); draw(); return;
    }
    if(!pvActive) startPV(closest); else extendPV(closest);
    renderCandList(); draw();
});
document.addEventListener('mousemove', e => {
    if(!regionDrag) return;
    const {r,c}=canvasToRC(e.clientX,e.clientY);
    const cl=clampRC(r,c); regionEnd={r:cl.r,c:cl.c}; draw();
});
document.addEventListener('mouseup', e => {
    if(!regionDrag) return;
    regionDrag=false; canvas.classList.remove('region-drag');
    if(regionStart&&regionEnd){
        const rr=normalizeRegion(regionStart,regionEnd);
        regionRect=(rr.r1===rr.r2&&rr.c1===rr.c2)?null:rr;
    }
    draw(); if(realtimeOn&&regionRect) triggerRealtime();
});

/* ================================================================
   수순 이동 및 UI 연동
================================================================ */
function navPrev(){
    if(!boardHistory.length) return;
    const snap=boardHistory.pop();
    futureStack.push({board:JSON.parse(JSON.stringify(board)), move:moveHistory[moveHistory.length-1], koPoint});
    board    = snap.board; koPoint  = snap.koPoint ?? null; moveHistory.pop();
    turn=moveHistory.length===0?1:(moveHistory[moveHistory.length-1].color===1?2:1);
    candidates=[]; clearPV(); updateTurnUI(); draw();
    if(realtimeOn) triggerRealtime();
}
function navNext(){
    if(!futureStack.length) return;
    const snap=futureStack.pop();
    boardHistory.push({board:JSON.parse(JSON.stringify(board)), move:snap.move, koPoint});
    moveHistory.push(snap.move); board    = snap.board; koPoint  = snap.koPoint ?? null;
    turn=snap.move.color===1?2:1; candidates=[]; clearPV(); updateTurnUI(); draw();
    if(realtimeOn) triggerRealtime();
}
function navFirst(){ while(boardHistory.length) navPrev(); }
function navLast() { while(futureStack.length)  navNext(); }
function updateNavButtons(){
    document.getElementById('nav-prev').disabled  = boardHistory.length===0;
    document.getElementById('nav-first').disabled = boardHistory.length===0;
    document.getElementById('nav-next').disabled  = futureStack.length===0;
    document.getElementById('nav-last').disabled  = futureStack.length===0;
    const total=moveHistory.length+futureStack.length;
    document.getElementById('move-counter').textContent = total>0?`${moveHistory.length} / ${total}수`:'0수';
}
function updateTurnUI(){
    const s=document.getElementById('turn-stone'); const t=document.getElementById('turn-text');
    if(turn===1){s.className='';s.style.background='#111';t.textContent='흑 (Black)';}
    else{s.className='white';s.style.background='#f0f0f0';t.textContent='백 (White)';}
}
function setStoneMode(mode){
    stoneMode=mode;
    ['black','auto','white'].forEach(k=>{
        const el=document.getElementById(`pick-${k}`);
        el.className='stone-opt'+(k===mode?` ${k}-active`:'');
    });
}
function toggleNumbers(){
    showNumbers=!showNumbers; const btn=document.getElementById('toggle-num');
    btn.textContent=`수순 표시: ${showNumbers?'ON':'OFF'}`; btn.classList.toggle('active',showNumbers); draw();
}
function toggleResearchMode(){
    if(!isResearching || (pvActive && pvChain.length>0)){
        if(!branchSnapshot){
            branchSnapshot = { board: JSON.parse(JSON.stringify(board)), moveHistory: JSON.parse(JSON.stringify(moveHistory)), turn, koPoint };
            document.getElementById('branch-reset-btn').style.display='block'; nextResearchNum = 1;
        }
        if(pvActive && pvChain.length>0){
            pvChain.forEach(({move, isBlack, num})=>{
                const {r,c}=gtpToRC(move); if(r<0||r>=SIZE||c<0||c>=SIZE||board[r][c]!==0) return;
                const color=isBlack?1:2; boardHistory.push({board: JSON.parse(JSON.stringify(board)), move:{color,r,c}, koPoint});
                moveHistory.push({color, r, c, num}); board[r][c]=color;
            });
            const last=pvChain[pvChain.length-1]; turn=last.isBlack?2:1;
            futureStack=[]; nextResearchNum = last.num + 1; pvChain=[]; pvCandidates=[]; pvActive=false; updateTurnUI();
        }
        isResearching=true; researchStart=moveHistory.length;
    } else {
        if(branchSnapshot){
            board = branchSnapshot.board; moveHistory = branchSnapshot.moveHistory; turn = branchSnapshot.turn; koPoint = branchSnapshot.koPoint;
            boardHistory=[]; futureStack=[]; branchSnapshot=null; document.getElementById('branch-reset-btn').style.display='none';
        }
        isResearching=false; researchStart=0; nextResearchNum=1; candidates=[]; clearPV(); updateTurnUI(); renderCandList();
    }
    const btn=document.getElementById('research-btn');
    btn.textContent=isResearching?'🔬 놓아보기 종료':'🔬 놓아보기 시작'; btn.classList.toggle('active',isResearching); draw();
    if(realtimeOn) triggerRealtime();
}
function toggleRegionMode(){
    regionMode=!regionMode;
    if(!regionMode){ regionRect=null; regionStart=null; regionEnd=null; regionDrag=false; canvas.classList.remove('region-drag'); }
    const btn=document.getElementById('region-btn');
    btn.textContent=`⬚ 부분 연구 모드: ${regionMode?'ON':'OFF'}`; btn.classList.toggle('active',regionMode);
    document.getElementById('region-reset-btn').style.display=regionMode?'block':'none'; draw();
}
function resetRegion(){ regionRect=null; regionStart=null; regionEnd=null; regionDrag=false; canvas.classList.remove('region-drag'); draw(); }
function resetToBranch(){
    if(!branchSnapshot) return;
    board = branchSnapshot.board; moveHistory = branchSnapshot.moveHistory; turn = branchSnapshot.turn; koPoint = branchSnapshot.koPoint;
    boardHistory=[]; futureStack=[]; isResearching=false; researchStart=0; nextResearchNum=1;
    candidates=[]; clearPV(); branchSnapshot=null;
    document.getElementById('branch-reset-btn').style.display='none';
    document.getElementById('research-btn').textContent='🔬 놓아보기 시작';
    document.getElementById('research-btn').classList.remove('active');
    updateTurnUI(); renderCandList(); draw(); if(realtimeOn) triggerRealtime();
}
function setSpeed(level){
    lzVisits=SPEED_MAP[level];
    ['fast','normal','deep'].forEach(k=>document.getElementById(`speed-${k}`).classList.toggle('active',k===level));
}
function saveSGF(){
    let sgf='(;FF[4]GM[1]SZ[19]';
    moveHistory.forEach(m=>{sgf+=`;${m.color===1?'B':'W'}[${String.fromCharCode(97+m.c)}${String.fromCharCode(97+m.r)}]`;});
    sgf+=')'; const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([sgf],{type:'text/plain'}));
    a.download='game.sgf'; a.click();
}
function resetBoard(){ branchSnapshot=null; location.reload(); }
function toggleRealtime(){
    realtimeOn=!realtimeOn; const btn=document.getElementById('realtime-btn'); const man=document.getElementById('manual-btn');
    if(realtimeOn){
        btn.textContent='⚡ 실시간 AI: ON'; btn.classList.add('realtime-on');
        man.disabled=true; man.style.opacity='0.4'; triggerRealtime();
    } else {
        btn.textContent='⚡ 실시간 AI: OFF'; btn.classList.remove('realtime-on');
        man.disabled=false; man.style.opacity='1'; document.getElementById('ai-status').textContent='';
        branchSnapshot ? clearPVKeepOffset() : clearPV(); renderCandList(); draw();
    }
}
function triggerRealtime(){
    clearTimeout(realtimeTimer);
    if(isAnalyzing){ pendingAnalysis=true; } else realtimeTimer=setTimeout(()=>requestAI(true),300);
}

/* ================================================================
   AI 통신 및 분석 (apiBase 적용)
================================================================ */

// ★ fetch 경로 치환
async function requestAI(silent=false, pvMode=false){
    if(isAnalyzing){ if(!silent) return; }
    isAnalyzing=true; pendingAnalysis=false;
    const snapshotLen=moveHistory.length, snapshotTurn=turn;
    document.getElementById('ai-status').innerHTML='<span class="spinner"></span>분석 중...';
    const gtpMoves=moveHistory.filter(m=>!m.isPass).map(m=>[m.color===1?'B':'W',rcToGTP(m.r,m.c)]);
    const analysisTurn = snapshotTurn;
    let regionPayload = null;
    if(regionMode && regionRect) regionPayload = { r1: regionRect.r1, c1: regionRect.c1, r2: regionRect.r2, c2: regionRect.c2 };
    const payload={ moves:gtpMoves, lz_visits:lzVisits, region_mode: !!regionPayload, region: regionPayload };
    try{
        const res=await fetch(`${apiBase}/analyze`,{
            method:'POST',headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)
        });
        const data=await res.json();
        if(moveHistory.length!==snapshotLen){ isAnalyzing=false; if(realtimeOn)triggerRealtime(); return; }
        let cands=data.candidates||[];
        if(regionRect){
            const inR  = (data.in_region_candidates || cands.filter(c=>isInRegion(c.move))).slice(0,3);
            const outR = cands.filter(c=>!isInRegion(c.move)).slice(0,3);
            cands=[...inR,...outR];
        }
        candidates=cands.map(c=>({...c, _turn: analysisTurn}));
        if(!pvActive) pvCandidates=[];
        const blackWr=(analysisTurn===1)?data.winrate:(100-data.winrate);
        const scoreLead=data.score_lead_black??null;
        const inRegionCands = regionRect ? cands.filter(c=>isInRegion(c.move)) : [];
        const regionWr = inRegionCands.length>0 ? (snapshotTurn===1 ? inRegionCands[0].winrate : 100-inRegionCands[0].winrate) : null;
        wrHistory.push({moveNum:snapshotLen, blackWr, scoreLead, regionWr}); chartOffset = 0;
        if(data.ownership && data.ownership.length === SIZE*SIZE){
            ownershipData = data.ownership; document.getElementById('ownership-btn-research').style.display = 'block';
            if(showOwnership) updateOwnershipScore();
        }
        const slText=scoreLead!==null?`  (${scoreLead>0?'+':''}${scoreLead}집)`:'';
        document.getElementById('ai-status').textContent=`✅ ${data.best_move}  ${data.winrate}%${slText}`;
        renderCandList(); updateWinrateBar(blackWr,scoreLead); drawWinrateChart(); draw();
    }catch(e){
        if(!silent) alert('서버 연결 실패!'); document.getElementById('ai-status').textContent=realtimeOn?'⚠ 연결 대기 중...':'연결 오류';
    }finally{
        isAnalyzing=false;
        if(pendingAnalysis&&realtimeOn){ pendingAnalysis=false; realtimeTimer=setTimeout(()=>requestAI(true),100); }
    }
}

function isInRegion(move){ if(!regionRect) return true; const {r,c}=gtpToRC(move); return r>=regionRect.r1&&r<=regionRect.r2&&c>=regionRect.c1&&c<=regionRect.c2; }
function renderCandList(){
    const list=document.getElementById('cand-list'); const displayCands = pvActive ? pvCandidates : candidates;
    if(!displayCands.length){ list.innerHTML=`<div class="no-data">${pvActive?'pv 분석 중...':'분석 결과 없음'}</div>`; return; }
    const maxV=displayCands[0].visits||1;
    let html = pvActive ? `<div style="font-family:'JetBrains Mono',monospace;font-size:.58rem;color:#9c27b0;padding:2px 2px 5px;letter-spacing:.1em;">▶ pv+${pvChain.length}수 이후 추천</div>` : '';
    const items = regionRect ? (() => {
                const inR  = displayCands.filter(c=>isInRegion(c.move)).slice(0,3);
                const outR = displayCands.filter(c=>!isInRegion(c.move)).slice(0,3);
                return [...(inR.length?[`<div style="font-family:'JetBrains Mono',monospace;font-size:.58rem;color:var(--dim);padding:4px 2px 2px;">● 영역 내</div>`]:[]), ...inR.map((c,i)=>candHTML(c,i,'in',displayCands.indexOf(c))),
                        ...(outR.length?[`<div style="font-family:'JetBrains Mono',monospace;font-size:.58rem;color:var(--dim);padding:4px 2px 2px;">○ 영역 밖</div>`]:[]), ...outR.map((c,i)=>candHTML(c,i,'out',displayCands.indexOf(c)))];
            })() : displayCands.slice(0,3).map((c,i)=>candHTML(c,i,'normal',i));
    html += items.join(''); list.innerHTML = html;
    list.querySelectorAll('.cand-item').forEach(el=>{
        const idx=parseInt(el.dataset.idx); el.addEventListener('contextmenu', e=>{ e.preventDefault(); const src = pvActive ? pvCandidates : candidates; const cand = src[idx]; if(!cand) return; if(!pvActive) startPV(cand); else extendPV(cand); renderCandList(); draw(); });
    });
}
function candHTML(c, rank, mode, globalIdx){
    const colorOf=(m,r)=>{ if(m==='in') return r===0?'#00e5ff':'#4dd0e1'; if(m==='out') return r===0?'#ff9800':'#ffcc80'; return rank===0?COLOR_TOP:COLOR_REST; };
    const col=colorOf(mode,rank); const maxV=(pvActive?pvCandidates:candidates)[0]?.visits||1;
    const barW=Math.round(c.visits/maxV*100); const pvTag=c.pv&&c.pv.length>0?`<span style="font-size:.5rem;color:#556;margin-left:3px;">↪${c.pv.length}수</span>`:'';
    return `<div class="cand-item" data-idx="${globalIdx}"><div class="cand-badge" style="background:${col}">${rank+1}</div><div class="cand-move">${c.move}${pvTag}</div><div class="cand-wr">${c.winrate}%</div><div class="cand-bar-bg"><div class="cand-bar" style="width:${barW}%;background:${col}"></div></div></div>`;
}
function updateWinrateBar(blackWr,scoreLead){
    document.getElementById('wr-bar-wrap').style.display='block'; const bPct=Math.max(2,Math.min(98,blackWr));
    document.getElementById('wr-black-pct').textContent=blackWr.toFixed(1)+'%'; document.getElementById('wr-white-pct').textContent=(100-blackWr).toFixed(1)+'%';
    document.getElementById('wr-bar-black').style.width=bPct+'%'; document.getElementById('wr-bar-white').style.width=(100-bPct)+'%';
    if(scoreLead!==null){ const who=scoreLead>=0?'흑':'백'; document.getElementById('wr-score-label').textContent=`집차이: ${who} +${Math.abs(scoreLead).toFixed(1)}`; }
    else document.getElementById('wr-score-label').textContent='집차이: -';
}
function drawWinrateChart(){
    const cv=document.getElementById('chart-canvas'); const ph=document.getElementById('chart-ph'); const hint=document.getElementById('chart-hint'); const n=wrHistory.length; if(n<1){ ph.style.display='block'; hint.style.display='none'; return; } ph.style.display='none';
    const winSize=Math.min(CHART_WINDOW, n); const maxOffset=Math.max(0, n-winSize); chartOffset=Math.max(0, Math.min(maxOffset, chartOffset));
    const endIdx=n-chartOffset; const startIdx=Math.max(0, endIdx-winSize); const slice=wrHistory.slice(startIdx, endIdx); const sn=slice.length; hint.style.display=n>CHART_WINDOW?'block':'none';
    const cDPR=devicePixelRatio||1; cv.width=cv.offsetWidth*cDPR; cv.height=cv.offsetHeight*cDPR; const cx=cv.getContext('2d'); cx.scale(cDPR, cDPR);
    const W=cv.offsetWidth, H=cv.offsetHeight; const ML=24, MR=6, MT=6, MB=6; const gW=W-ML-MR, gH=H-MT-MB; cx.clearRect(0,0,W,H); cx.fillStyle='#161a1e'; cx.fillRect(0,0,W,H);
    cx.strokeStyle='rgba(255,255,255,0.07)'; cx.lineWidth=1; cx.setLineDash([3,3]); cx.beginPath(); cx.moveTo(ML,MT+gH/2); cx.lineTo(W-MR,MT+gH/2); cx.stroke(); cx.setLineDash([]);
    const ptX=i=>sn<2?ML+gW/2:ML+i*gW/(sn-1); const ptY=wr=>MT+gH-(wr/100)*gH;
    if(sn>=2){ cx.beginPath(); cx.moveTo(ptX(0),MT+gH/2); slice.forEach((p,i)=>cx.lineTo(ptX(i),ptY(p.blackWr))); cx.lineTo(ptX(sn-1),MT+gH/2); cx.closePath(); cx.fillStyle='rgba(100,221,23,0.1)'; cx.fill();
               cx.beginPath(); slice.forEach((p,i)=>i===0?cx.moveTo(ptX(0),ptY(p.blackWr)):cx.lineTo(ptX(i),ptY(p.blackWr))); cx.strokeStyle='#64dd17'; cx.lineWidth=1.8; cx.stroke(); }
    slice.forEach((p,i)=>{ const x=ptX(i), y=ptY(p.blackWr); cx.beginPath(); cx.arc(x,y,2.5,0,Math.PI*2); cx.fillStyle='#64dd17'; cx.fill(); });
}
function setAppMode(mode) { appMode=mode; document.getElementById('game-panel').style.display=mode==='game'?'flex':'none'; document.getElementById('research-panel').style.display=mode==='research'?'flex':'none'; document.getElementById('tab-game').classList.toggle('active',mode==='game'); document.getElementById('tab-research').classList.toggle('active',mode==='research'); }

/* ================================================================
   대국 시스템 및 AI 연동
================================================================ */
function adjustKomi(delta) { gameKomi = Math.round((gameKomi+delta)*2)/2; updateKomiUI(); }
function resetKomi() { gameKomi = 6.5; updateKomiUI(); }
function updateKomiUI() { const el=document.getElementById('komi-display'); if(el) el.textContent=`${gameKomi}집`; }
function setHandicap(n) { gameHandicap=n; [0,2,3,4,6,9].forEach(k=>{ const el=document.getElementById(`hc-${k}`); if(el) el.className='stone-opt'+(k===n?' auto-active':''); }); }
function setUndoLimit(n) { undoLimit=n; ['undo-0','undo-3','undo-inf'].forEach(id=>document.getElementById(id).className='stone-opt'); const el=document.getElementById(`undo-${n===-1?'inf':n}`); if(el) el.className='stone-opt auto-active'; }

// ★ fetch 경로 치환
async function requestHint() {
    if(!gameActive || aiThinking) return; if(turn !== playerColor) return;
    const statusEl = document.getElementById('game-status'); statusEl.innerHTML = '<span class="spinner"></span>힌트 계산 중...';
    const gtpMoves = moveHistory.filter(m=>!m.isPass).map(m=>[m.color===1?'B':'W', rcToGTP(m.r,m.c)]);
    try {
        const res = await fetch(`${apiBase}/analyze`, {
            method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ moves: gtpMoves, lz_visits: lzVisits, region_mode: false })
        });
        const data = await res.json(); candidates = (data.candidates||[]).map(c=>({...c, _turn: turn})); setGameStatus(`힌트: ${data.best_move} 추천`); renderCandList(); draw();
    } catch(e) { setGameStatus('⚠ 힌트 오류'); }
}

// ★ fetch 경로 치환
async function requestScore() {
    if(!gameActive || aiThinking) return;
    const gtpMoves = moveHistory.filter(m=>!m.isPass).map(m=>[m.color===1?'B':'W', rcToGTP(m.r, m.c)]);
    try {
        const res = await fetch(`${apiBase}/score`, {
            method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ moves: gtpMoves, komi: gameKomi })
        });
        const data = await res.json(); scoreResult = data; showScoreModal(data);
    } catch(e) { setGameStatus('⚠ 계가 오류'); }
}

// ★ fetch 경로 치환
async function requestAIMove() {
    if (!gameActive || aiThinking) return; aiThinking = true; draw();
    document.getElementById('game-status').innerHTML = '<span class="spinner"></span>AI 생각 중...';
    const gtpMoves = moveHistory.filter(m=>!m.isPass).map(m=>[m.color===1?'B':'W', rcToGTP(m.r, m.c)]);
    try {
        const res = await fetch(`${apiBase}/genmove`, {
            method: 'POST', headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ moves: gtpMoves, level: aiLevel, komi: gameKomi, handicap: gameHandicap })
        });
        const data = await res.json(); if (data.status !== 'success') throw new Error();
        const aiMove = data.move;
        if (aiMove === 'RESIGN') { endGame('AI가 기권했습니다.'); return; }
        if (aiMove === 'PASS') {
            passCount++; moveHistory.push({ color: turn, r: -1, c: -1, isPass: true }); turn = turn===1?2:1;
            if (passCount >= 2) { endGame('양측 패스 — 종료'); return; }
            setGameStatus('AI 패스');
        } else {
            passCount = 0; const {r, c} = gtpToRC(aiMove); const result = tryPlace(r, c, turn);
            if (result) { boardHistory.push({board: JSON.parse(JSON.stringify(board)), move:{color:turn,r,c}, koPoint}); moveHistory.push({color: turn, r, c}); board = result.newBoard; koPoint = result.koPoint; }
            turn = turn === 1 ? 2 : 1;
        }
        aiThinking = false; updateTurnUI(); draw(); setGameStatus(`${turn===1?'흑':'백'} 차례`);
        if (data.winrate !== null) updateGameWinrate(data.winrate, data.score_lead_black, data.ownership);
    } catch(e) { aiThinking = false; draw(); setGameStatus('⚠ 서버 연결 오류'); }
}

/* ================================================================
   기보 파서 및 기타 기능 (원본 유지)
================================================================ */
function parseSGF(text) {
    const result = { meta: {}, moves: [] };
    function extractProps(src) {
        const props = {}; const re = /([A-Z]+)\[([^\]]*)\]/g; let m;
        while((m = re.exec(src)) !== null) { const key = m[1], val = m[2]; if(props[key] === undefined) props[key] = val; else if(Array.isArray(props[key])) props[key].push(val); else props[key] = [props[key], val]; }
        return props;
    }
    function sgfCoordToRC(coord) { if(!coord || coord === '' || coord === 'tt') return null; return {c:coord.charCodeAt(0)-97, r:coord.charCodeAt(1)-97}; }
    let depth=0; let nodeText=''; const nodes=[];
    for(let i=0;i<text.length;i++){ const ch=text[i]; if(ch==='('){ if(depth===1) nodeText=''; depth++; } else if(ch===')'){ depth--; } else if(depth===1){ if(ch===';'){ if(nodeText.trim()) nodes.push(nodeText.trim()); nodeText=''; } else nodeText+=ch; } }
    if(nodeText.trim()) nodes.push(nodeText.trim());
    if(nodes.length>0){ const meta=extractProps(nodes[0]); result.meta={ black:meta.PB||'', white:meta.PW||'', result:meta.RE||'', komi:meta.KM?parseFloat(meta.KM):null, date:meta.DT||'' }; }
    for(let i=1;i<nodes.length;i++){
        const props=extractProps(nodes[i]); let color=null, coord=null;
        if(props.B!==undefined){color=1;coord=props.B;} else if(props.W!==undefined){color=2;coord=props.W;}
        if(color===null)continue; const rc=sgfCoordToRC(coord);
        if(rc) result.moves.push({color, r:rc.r, c:rc.c, isPass:false}); else result.moves.push({color, r:-1, c:-1, isPass:true});
    }
    return result;
}
function loadSGFData(parsed) {
    board=Array.from({length:SIZE},()=>Array(SIZE).fill(0)); boardHistory=[]; moveHistory=[]; futureStack=[]; turn=1; koPoint=null;
    sgfMoves=parsed.moves; sgfLoaded=true; sgfCurrent=0; if(parsed.meta.komi!==null){ gameKomi=parsed.meta.komi; updateKomiUI(); }
    document.getElementById('sgf-slider').max=sgfMoves.length; document.getElementById('sgf-slider').value=0; document.getElementById('sgf-nav-wrap').style.display='block';
    const m=parsed.meta; document.getElementById('meta-black').textContent=m.black; document.getElementById('meta-white').textContent=m.white; document.getElementById('meta-result').textContent=m.result; document.getElementById('meta-komi').textContent=m.komi; document.getElementById('meta-date').textContent=m.date; document.getElementById('sgf-meta').style.display='block';
    showNumbers=true; document.getElementById('toggle-num').classList.add('active'); updateTurnUI(); draw();
}
function seekSGF(targetMove) {
    if(!sgfLoaded) return; board=Array.from({length:SIZE},()=>Array(SIZE).fill(0)); boardHistory=[]; moveHistory=[]; koPoint=null; turn=1;
    for(let i=0;i<targetMove&&i<sgfMoves.length;i++){
        const m=sgfMoves[i]; if(m.isPass){ moveHistory.push({color:m.color,r:-1,c:-1,isPass:true}); turn=turn===1?2:1; continue; }
        const result=tryPlace(m.r, m.c, m.color); if(result){ boardHistory.push({board:JSON.parse(JSON.stringify(board)),move:{color:m.color,r:m.r,c:m.c},koPoint}); moveHistory.push({color:m.color,r:m.r,c:m.c}); board=result.newBoard; koPoint=result.koPoint; }
        turn=m.color===1?2:1;
    }
    sgfCurrent=targetMove; document.getElementById('sgf-move-label').textContent=`${targetMove}/${sgfMoves.length}수`; draw(); updateNavButtons(); if(realtimeOn) triggerRealtime();
}
function handleSGFDrop(e) { e.preventDefault(); document.getElementById('sgf-drop-zone').classList.remove('drag-over'); const file=e.dataTransfer.files[0]; if(file) readGameFile(file); }
function handleSGFFile(input) { const file=input.files[0]; if(file) readGameFile(file); input.value=''; }
function readGameFile(file) { const reader=new FileReader(); reader.onload=e=>{ const parsed=parseSGF(e.target.result); loadSGFData(parsed); }; reader.readAsText(file); }
function startGame() { board=Array.from({length:SIZE},()=>Array(SIZE).fill(0)); boardHistory=[]; moveHistory=[]; futureStack=[]; turn=1; koPoint=null; gameActive=true; document.getElementById('game-btns').style.display='flex'; updateTurnUI(); draw(); setGameStatus('대국 시작!'); if(playerColor===2) requestAIMove(); }
function setGameStatus(msg) { document.getElementById('game-status').textContent=msg; }
function updateGameWinrate(wr, sl, own) { document.getElementById('game-wr-black').textContent=`${wr}%`; document.getElementById('game-wr-white').textContent=`${100-wr}%`; document.getElementById('game-bar-black').style.width=`${wr}%`; }
function showScoreModal(data) { document.getElementById('modal-black').textContent=data.black; document.getElementById('modal-white').textContent=data.white; document.getElementById('modal-result').textContent=data.winner==='black'?'흑 승':'백 승'; document.getElementById('score-modal').style.display='flex'; }
function confirmScoreModal(agree) { document.getElementById('score-modal').style.display='none'; if(agree) endGame('대국 종료'); }
function endGame(msg) { gameActive=false; setGameStatus(msg); document.getElementById('game-btns').style.display='none'; document.getElementById('game-review-btn').style.display='block'; }
function goToReview() { setAppMode('research'); draw(); }

document.addEventListener('keydown', e => {
    if(e.key==='ArrowLeft') sgfLoaded?seekSGF(sgfCurrent-1):navPrev();
    else if(e.key==='ArrowRight') sgfLoaded?seekSGF(sgfCurrent+1):navNext();
});

updateTurnUI(); draw();
</script>
</body>
</html>
