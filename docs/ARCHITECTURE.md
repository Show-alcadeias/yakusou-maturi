# アーキテクチャ

## 責務
|部品|担当|担当しないこと|
|---|---|---|
|DM v4.2.0 / story.dialogue|本文、条件付き本文・応答、選択後の状態操作呼び出し|保存、UI構築|
|GameState（ExpeditionState）|選択履歴、薬草、探索フラグ、救出状態、行動適用と妥当性確認|イベント遷移、描画|
|GameFlow|現在イベント、DMの次行取得、探索の有限化、開始地点保存、再開|条件式の独自評価、本文|
|GameUI|タイトル・本文・応答・状態表示、キーボードとマウス|物語の分岐判断|
|MediaAdapter|イベントIDの通知を受け外部演出へ中継|進行の成否を決定|
|Audio（Ver.0.2）|AudioStreamPlayerで1曲の再生・停止・ループ・切替|背景、物語の進行|
|Visual（Ver.0.2）|TextureRectで背景の表示・切替・クリア|音楽、物語の進行|

GameStateはRefCounted。GameFlowが所有し、DMへ `[{"state": state, "flow": self}]` を明示的に渡す。状態を自動読み込みの大域変数にせず、テストごとに独立した周回を作る。DMランタイムだけは公式のAutoloadを利用する。

## データの流れ
`UI → GameFlow.choose(index) → DM.get_next_dialogue_line → state.act(action_id) / flow.go(event_id) → 行表示signal → UI`

イベント終端でGameFlowが次のイベントを開始。探索先の選択はDM、許可イベントIDと共通進行順・3回上限はGameFlow。本文をGameFlowへ複製しない。

セーブは `user://expedition_save.json`。形式番号、イベントID、GameStateのスナップショットを保存し、同一ディレクトリの一時ファイルから置換する。イベント開始時に保存し、「つづきから」はそのイベントの冒頭から再開する。表示行・DM内部ID・応答オブジェクトは永続化しない。新しい周回開始で前の1枠を更新することをタイトルに明示する。破損・異版・未知IDは拒否し、新規開始を可能にする。

## メディアの接続（Ver.0.2）
既存の `event_started(event_id) → MediaAdapter.cue_requested(event_id)` を維持。Adapterが `media/catalog.json` を参照し、`bgm_requested(id, path)` / `background_requested(id, path)` を発行する。AudioとVisualは各チャンネルだけを購読し、互いを参照しない。対応表には各イベントの最終状態を明示し、セーブへメディア状態を追加せずイベント再通知だけで復元する。

`scenes/media_layer.tscn` は3部品と暗幕の配線・配置だけを行う。GameUIが任意シーンの存在を確認して最背面に追加する。シーンなし、片側なし、両側なしが有効。空IDは停止／クリア。未知ID・欠落・型違いは該当チャンネルを停止／クリアし、診断signalだけを通知して進行を待たせない。GameFlowとGameStateには変更を加えていない。

UIのタイトル表示だけは `title` cueを使い、音を止めて街背景へ戻す。これは物語の11イベントには含めない。交換には同じ名前のノードと2引数のメソッドだけが必要で、共通基底クラスやプラグイン登録機構は設けない。詳細は [MEDIA_EXTENSION_PLAN.md](MEDIA_EXTENSION_PLAN.md)。

## 将来の接続
- 効果音・立ち絵：必要時にAdapterの通知を追加。会話途中の変更が必要ならDMタグをAdapterへ渡す。今回のBGM・背景にはタグや本文変更は不要。
- ダイス：必要なイベントで外部判定モジュールをGameFlowへ接続し、結果のみGameStateに記録してDM条件から参照。今回乱数は使わない。
- 戦闘：GameFlowのイベント完了境界で外部シーンへ移動し、結果を状態へ戻す。会話中の非同期戦闘基盤を先に作らない。
- アイテム：現状の薬草数・品質を必要時にアイテムモジュールへ移し、GameState側に会話向け問い合わせを保つ。

上記は拡張方針であり、未使用のインターフェース群や汎用StoryCoreは実装しない。

## UIとプラットフォーム
Godot Control、RichTextLabel、ScrollContainer、Buttonを使用。本文は即時全表示し、インライン副作用・タイプライター演出は使わない。日本語フォント同梱でLinuxのシステムフォントに依存しない。Compatibilityレンダラー、2Dのみ、通信不要。Web向けにネイティブ拡張・スレッド・OS固有APIを避ける。Webのuser://はブラウザ保存領域であり、消去・プライベート閲覧で永続性が失われる。
