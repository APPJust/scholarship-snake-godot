# 獎學金衝刺：文件貪食蛇

署名：**資通系 李振偉老師**

Godot 4.7.2 / GDScript 製作，真正 WebAssembly 匯出。

- 遊玩網址：https://appjust.github.io/scholarship-snake-godot/
- 原始碼：https://github.com/APPJust/scholarship-snake-godot

## 主角與規則
資通系大學生「小青」在獎學金截止前收集文件；尾端是越收越長的文件隊伍。
每輪 75 秒，成績單、推薦信、自傳各收 2 份即過關。每份 100 分，過關另加向上取整的剩餘秒數 × 10 分。
三輪全過獲勝。撞牆、撞到自己、撞路障或超時即失敗；可重玩或回首頁。

| 輪次 | 每格秒數 | 路障 |
|---|---|---|
| 第一輪 | 0.26 | 0 |
| 第二輪 | 0.21 | 4 |
| 第三輪 | 0.17 | 6 |

- 電腦：方向鍵 / WASD，或滑鼠點方向鈕。
- 手機：畫面方向鈕或滑動。方向輸入最多緩衝兩步，不可直接反向。
- P / Esc 或左上方按鈕暫停；切離視窗自動暫停，恢復提供 1 秒準備時間。
- 每輪開始有 1.5 秒看場地時間，不扣倒數。
- 每關重設隊伍和文件，累積總分。最高分只存在本機瀏覽器。
- 尾巴當步離開的格子可以進入，符合標準貪食蛇規則。

## 開發與匯出
用 Godot 4.7.2 開啟 `project.godot`。安裝同版本 Web export templates。

```powershell
python tools/generate_audio.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/game_test.gd
godot --headless --path . --export-release Web web/index.html
python -m http.server 8144 --directory web
```

Compatibility renderer、單執行緒，無須 COOP/COEP，適用 GitHub Pages。依 [Godot 官方文件](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)。請使用 HTTP/HTTPS，不要直接雙擊 HTML。首次載入約 51 MB 未壓縮資源，包含引擎與中文字型；需支援 WebGL 2 與 WebAssembly。

`.github/workflows/deploy.yml` 發布 `web/`，Pages Source 使用 GitHub Actions。改遊戲後須重新匯出並提交產物。

## 素材與授權
- `assets/campus.png`：內建 OpenAI ImageGen 生成的首頁插畫，1774 × 887 PNG。完整提示見 `IMAGE_PROMPT.md`。
- 遊戲圖形：本專案 Godot 程式原創繪製。
- 四種音效：本專案 Python 原創合成，可依 CC0 使用。
- 字型：沿用工作區 Noto Sans TC，來源 https://github.com/google/fonts/tree/main/ofl/notosanstc ，SIL Open Font License 1.1，全文 `assets/fonts/OFL.txt`。
- Godot：MIT，https://godotengine.org/license/ 。

## 驗證
`qa/game-tests.json`：19 項規則測試及 300 組隨機生成位置檢查。通關測試會安排碰撞前的位置以隔離規則，不代表真人玩出通關成績。
`window.scholarshipState` 是本頁唯讀驗證快照，只顯示狀態，不提供作弊或修改介面，不上傳任何資料。
