# Ver.0.2 メディア後付け計画（実装前）

## Inspect：既存の確認
基準：`origin/main` の `de7ab42`（MVP PR #1のマージ）。作業ブランチ：`develop/media-v0.2`。

GameFlow、GameState、GameUI、MediaAdapter、story.dialogue、既存のARCHITECTURE / IMPLEMENTATION_REVIEW / TEST_RESULTSと全テストを確認した。Flowは新規開始・ロードとも `_enter()` から `event_started(event_id)` を発行する。Adapterは既に `cue_requested(event_id)` を中継する。UIが接続を組み立て、シナリオはメディアに依存していない。ここをそのまま利用する。

## Think：比較と採用理由
|論点|比較|採用|
|---|---|---|
|接続点|既存signal / 新イベントバス|既存 `event_started → cue_requested` を維持。新しいバスやプラグイン管理は不要|
|対応表|JSON / Godot Resource|JSON。11イベントと5アセットには十分。ファイル参照を文字列で保持し、欠落を存在確認してフォールバックできる。Resourceはエディタの型付けに優れるが、参照先欠落がロードに影響しやすい|
|命令|前イベントからの差分 / 各イベントの完全指定|各イベントにBGM・背景を完全指定。履歴なしのロードでも復元可能|
|省略時|以前の演出を保持 / 停止・クリア|停止・クリア。欠落時に前のイベントの音楽や絵が残らない|
|UIへの導入|必須preload / 任意シーン1個|任意シーンをパスで読み込む。未設定・ファイルなしなら既存の文字だけのUI|
|画像・音源|外部サービス / 手製の仮素材|単純なオリジナルSVG3枚と、標準Pythonだけで合成する短いWAV2曲。外部生成API・追加ライブラリなし|

## Plan：責務と接続
- **GameFlow / DM / GameState**：変更しない。11イベント、選択肢、本文、状態変数、保存形式番号1を維持する。
- **MediaAdapter**：既存の `cue_requested(event_id)` を残して受け取り、JSONのイベント表とアセット表を参照。`bgm_requested(asset_id, resource_path)` / `background_requested(asset_id, resource_path)` を通知。Node参照やメディアリソースを状態へ渡さない。
- **Audio**：AudioStreamPlayerを継承。BGMの安全な読み込み、ループ再生、停止、切替、同一ID・同一パスの再始動防止を担当。背景を知らない。
- **Visual**：TextureRectを継承。背景の安全な読み込み、切替、クリアを担当。音楽を知らない。
- **MediaLayerシーン**：3部品の配線と全画面配置だけを担当。Audio/Visualは片方だけでも両方なしでもよい。代替ノードは同じ2引数のメソッドを持てば接続でき、基底クラス・登録機構は不要。
- **GameUI**：任意のMediaLayerシーンを最背面に追加し、Flowを接続。タイトル表示時にUI用 `title` cueを通知する。GameFlowの11イベントには追加しない。

`GameFlow.event_started → MediaAdapter.on_event_started → cue_requested → JSON参照 → bgm/background_requested → 各ノード`

背景は入力を透過。全画面の暗幕を重ね、既存の日本語フォント・本文・選択肢を前面に維持する。ゲームUIの配置は作り直さない。

## アセットの正本と意味
`media/catalog.json` に次の2表を置く。
- `assets`：`bgm.mountain` / `bgm.discovery` / `background.town` / `background.mountain` / `background.stream` から `res://assets/media/...` への対応。
- `events`：既存11イベント＋UIのtitleから `bgm` / `background` のIDへの対応。空文字は明示的な停止／クリア。

prologueは街背景・無音。approach/explore/meadow/ridge/descentは山背景・山BGM。streamは沢背景・同じ山BGM。discovery/aidは山背景・発見BGM。appraisalは街背景・発見BGM。ending/titleは街背景・BGM停止。ゲーム処理コードに素材パスを埋め込まない。

## エラー・未接続・復元
|状況|処理|
|---|---|
|MediaLayerなし、パス未設定、シーン欠落|UIは追加を省略し、従来どおり文字だけで進行|
|Audioのみ／Visualのみ／両方なし|接続できる側だけ通知を購読。応答や完了signalを待たない|
|未知イベント、JSON欠落・破損・不正構造|診断signalを通知し、BGM停止・背景クリア。物語へエラーを返さない|
|未知アセットID、カテゴリ違い、不正パス|該当チャンネルだけ停止／クリアし診断。他チャンネルと物語は継続|
|アセットファイル欠落、リソース型違い|各プレイヤーが確認し、そのチャンネルを停止／クリア。存在しないファイルを直接loadしない|
|イベント切替|2チャンネルの最終状態を毎回通知|
|同一BGM|ID・パスが同じで再生中なら何もしない。背景だけ切り替え可能|
|BGM停止|空IDでstop。次に同じ曲を指定したときは先頭から再生|
|セーブから再開|既存 `_enter(event)` の再通知で2チャンネルを復元。メディア状態をセーブに追加しない|
|タイトルに戻る|UIのtitle cueでBGM停止・街背景へ。隠れたゲームのBGMを残さない|
|Webの自動再生制限|タイトルは無音。開始・再開の操作後にGodot標準AudioStreamPlayerが再生。ブラウザの出力・ミュート制限を無理に解除しない|

診断はメディア側のsignalと開発用警告のみ。進行側problemやセーブには接続しない。破損した任意のバイナリを完全検証する仕組みは作らないが、欠落・対応表不正・型違いは明示的に扱う。

## 実装・検証順
1. この計画を先にコミット。設計自己レビュー：Core変更不要、再開が履歴非依存、未接続時に待機なし、素材出典明確。重大矛盾なし。
2. 対応表、Adapter、Audio、Visual、任意シーンの順に実装。UIの配線だけ変更。
3. SVGとWAVを追加し、出典・生成手順を記録。
4. 既存734経路・19,052チェックを回帰検証。メディアなし全経路検証は既存テストを保持。
5. メディア命令の記録用代替ノード、実Audio/Visualノード、未知ID・欠落・停止・同一曲・全イベントの実ファイルロード復元を追加テスト。
6. UI全編を通常／各片側／両方なし／シーンなしで確認。Linux GUIの画像・日本語を目視、音声は命令・ミキサー出力・実機聴取を区別する。
7. 可能ならLinux/Webを書き出し、ブラウザを再検証。
8. MEDIA_EXTENSION_REVIEWへ変更範囲・独立性・負債・成功／未検証を記録し、READMEとARCHITECTUREを更新。開発ブランチへコミットしPR。mainへマージしない。

## 対象外
汎用エンジン、プラグイン管理、独自音声エンジン、クロスフェード、立ち絵、効果音、音量設定画面、戦闘・ダイス・アイテム、シナリオ改稿。必要になった時点で小さく追加する。
