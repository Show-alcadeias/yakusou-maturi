# テスト結果

実施日：2026-11-14（日本時間）。成功と未検証を分けて記録する。

## 環境
Linux x86_64、Godot 4.7.2 stable official（ed1daf0bf）、DM v4.2.0。GUIはXorg dummy画面＋Mesa llvmpipe（CPU描画）、WebはChromium＋SwiftShader。専用GPUは使用していない。フォントは同梱Noto Sans JP、ウェイト400を明示。

## ヘッドレス：成功
`tests/run.sh` で公式DMコンパイラ、実際のDMランタイム、GameFlowを使用。

```text
RESULT checks=19052 failures=0 completed_routes=734 transitions=10524 events=11 harvest_grades=3 rescue_speeds=2 aid_methods=3
CONDITIONS {"revisit_hidden":true,"rope_false":true,"rope_true":true,"shortcut_false":true,"shortcut_true":true,"sort_false":true,"sort_true":true}
```

- タイトルの新規開始から本文UIへの遷移、イベント切替時の本文消去。
- 全734応答経路の終端到達。探索順序の違いも含む。11イベントすべて到達。
- 採取数・品質・履歴の整合性、必ずレオ救出・帰還を経ること。
- 方針・目印・救出速度・救助手順が実際の本文に反映されること。
- 薬草評価3種類、救出速度2種類、救助手順3種類。
- DMが計算した `is_allowed` を使い、近道・ロープ・選別の真と偽をそれぞれ確認。探索済み地点が選べないことも確認。選択肢に条件タグを漏らさない。
- 全11イベント開始時の実ファイル保存と別GameFlowへのロード。途中の選択を巻き戻して再開できること。
- JSON破損、異版、未知イベント、改ざん状態、段階が合わない保存データを拒否し、検証だけで現在状態を書き換えない。
- 未取得ロープ、未知行動、重複行動を拒否。
- MediaAdapterや音声・画像モジュールを一切付けないFlowで全経路完走。
- インポート済みの環境だけでなく、`.godot` のない別ディレクトリでも初回インポート→全テストを再現。Godot実行エラーログなし。

走査は、各応答直前の状態をメモリ内で復元して全応答を選び直す。毎回タイトルから起動し直す734回のプロセステストではない。実ファイルのロードとUI入力は別のテストで確認する。

## GUI：成功

```text
GUI RESULT checks=28 failures=0 renderer=llvmpipe (LLVM 19.1.7, 256 bits) display=X11
```

実ウィンドウでEnterによる開始、クリックによる進行、↑↓の応答移動、全編のキー操作、結末→タイトル→クリックで再開を確認。640×480への実際のウィンドウ縮小と、フォーカスした最後の応答がスクロール内に現れることを確認した。シナリオ中の日本語コードポイントを同梱フォントが持つことも検証。

スクリーンショットを目視し、日本語の文字・折り返し・選択肢を確認：[タイトル](screenshots/title.png)、[条件付き近道がある探索画面](screenshots/exploration.png)。本文と応答は別のスクロール領域。縮小時も論理ビューポートを拡縮する。

この仮想ディスプレイではV-Sync切替非対応の警告が出る。音声デバイスなしの初回検証はALSAエラー後にダミーへ切替わったため、以後のGUI検証には `--audio-driver Dummy` を明示した。音声出力の動作確認とは扱わない。

## Linux書き出し：成功
公式4.7.2テンプレートをSHA512照合し、`--export-release Linux` が成功。生成した埋め込みPCK形式のx86_64実行ファイルを、Godotエディタを使わず `--headless --quit-after 3` で起動できた。GUIの全編操作は同じソースをエディタ実行ファイルで実施している。

## Web：成功
`--export-release Web` が成功。スレッド無効版をローカルHTTPで配信し、`tests/web_smoke.cjs` を実施。

```json
{"result":"PASS","errors":[],"checkpoint":"ending","rescued":true,"visited":["meadow","stream","ridge"],"persistedAfterReload":true}
```

ブラウザで新規開始から40回のキー入力により3地点→救助→結末へ到達。IndexedDB内の実際のセーブで `event=ending`、`rescued=true`、3地点の訪問履歴を検証。ページ再読み込み後に「つづきから」で結末冒頭へ戻ることをスクリーンショットで確認。ブラウザの実行エラーなし。PlaywrightとChromiumは検証環境にあるものを使用し、ゲームの依存には追加していない。

再現例（PlaywrightとChromiumが利用可能な環境）：

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
# 別ターミナルで
node tests/web_smoke.cjs
```

## 未検証・制約
Firefox、Safari、モバイル、Windows、macOS、ブラウザのプライベート閲覧、長時間の実機プレイは未検証。Webの全734経路走査は行っていない（共通のDM実行コードはLinuxヘッドレスで全走査）。音声・画像・戦闘などの将来モジュール、保存先ディスク障害や電源断の実機試験は行っていない。Web配信サービスへの公開は実施しない。
