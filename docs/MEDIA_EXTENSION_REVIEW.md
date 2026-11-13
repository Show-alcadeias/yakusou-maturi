# Ver.0.2 メディア拡張レビュー

## 結論と基準
基準main：`de7ab42`。Inspect → Think → Plan → Build → Test → Reviewの順で実施し、実装前の計画を先に独立コミットした。既存MVPを作り直さず、背景3枚・BGM2曲を後付けできた。部品の省略・交換・素材欠落でも物語が進むことを確認した。

`scripts/game_flow.gd`、`scripts/game_state.gd`、`story/story.dialogue` は基準mainと完全一致。イベント11個、応答、状態変数、セーブ形式番号1を維持。DM・Godot・フォントのバージョンも変更していない。

## 設計への評価
|問い|結果|
|---|---|
|1. 既存コードの変更量|ゲーム用の既存スクリプトはGameUIの17行追加・4行削除とMediaAdapterの52行追加・1行削除だけ。Coreと本文は変更0。ほかにJSON同梱用のexport設定、テスト・README・設計文書を更新|
|2. 追加モジュールの独立性|AudioはAudioStreamPlayer、VisualはTextureRect。各々IDとパスの2引数を受けるだけで、Flow・State・互いのノードを参照しない|
|3. 既存Adapterで十分か|`cue_requested(event_id)` の接続点と署名は十分だった。既存クラスに対応表の解決と2チャンネルのsignalを追加し、新しいバスや会話機構を作る必要はなかった|
|4. 不要な抽象化|共通基底クラス、サービス登録、汎用プラグイン管理、メディア状態のセーブを追加していない。MediaLayerはこの作品のノード配線と配置だけ|
|5. 取り外し|シーン未設定・シーン欠落・Audioのみ・Visualのみ・両方なしで完走。関連ファイルを除いた別コピーでも既存734経路が完走|
|6. 立ち絵・効果音|必要時にAdapterから専用signalを追加し、独立ノードへ接続できる。会話途中ならDMタグを受ける小さな拡張が必要。今回は先行実装しない|
|7. 新イベントの編集箇所|従来のシナリオ・FlowのID/遷移・テストに加え、catalog.jsonのeventsにbgmとbackgroundの最終IDを1行追加。新しい素材ならassets表にIDとパスを追加。既存曲・画像の再利用ではプレイヤーコード変更不要|

## 採用した実装
対応表はGodot Resourceと比較してJSONを採用。型安全なエディタ編集より、欠落パスをハード参照せずチェックしてフォールバックできることと、小さい2表だけで読めることを優先した。

全イベントがBGM・背景の最終状態を指定する。差分命令や「直前の音楽を維持する」という省略規則を作らなかったため、どのイベントから再開しても同じ入力になる。同一ID・同一パスで音楽が再生中ならAudioが何もしない。背景だけの変更とBGM継続を両立できる。

未知イベント・壊れた表は両方を停止／クリア、未知ID・欠落・型違いは該当側だけ停止／クリア。診断はメディア側signalと開発用警告へ出し、Flowのproblemや進行待ちへつながない。タイトルはUI用cueで無音にする。メディアの追加状態を保存する必要はなかった。

背景は最背面のTextureRect、暗幕の不透明度0.86、入力透過。既存本文UIを維持した。素材パスはcatalog.jsonに集約し、ゲームのイベント処理へ散在させていない。

## 検証結果（2026-11-13）

### ヘッドレスの論理・回帰：成功

Godot 4.7.2、標準SceneTreeテスト、音声出力のない環境で実施。

```text
RESULT checks=19052 failures=0 completed_routes=734 transitions=10524 events=11 harvest_grades=3 rescue_speeds=2 aid_methods=3
MEDIA RESULT checks=109 failures=0 completed_ui_modes=8 restored_events=11
```

既存全経路テストは変更せず再実行。追加テストでは以下を確認した。

- 山→沢で画像だけ切替し同じ曲は再始動しない。発見時に曲が切り替わり、救助手順中は継続。結末・タイトルで停止。
- 同一IDでも参照パスを差し替えた場合は切替。停止後の同曲指定は再生開始。
- 未知ID・未知イベント・対応表の破損／欠落・カテゴリ違い・res以外のパス・音声と画像の型違い・ファイル欠落を安全に扱う。
- 全11イベントの実ファイルセーブを別Flowへロードし、開始通知だけで背景・BGMが一致。メディアが状態を変更しない。
- UIを8構成（なし／シーン欠落／両方／音のみ／画像のみ／プレイヤー両方なし／記録用の別実装／不正素材）で同じ結末まで完走。最終GameStateがメディアなし時と一致。
- AudioStreamPlayer・TextureRectを継承しない記録用Nodeへ交換し、音楽の開始・切替・停止と背景の命令を受け取れる。

故障注入ケースでは、意図した診断WARNINGが出る。SCRIPT ERROR・ERROR・テスト失敗はない。

さらに別コピーから `scripts/media_*.gd`、`scenes/media_layer.tscn`、`media/`、`assets/media/` とメディア専用テストを物理的に除き、`.godot`なしで初回インポート→既存 `tests/run_tests.gd` を実行。同じ19,052チェック・734経路が成功した。単に再生命令を無視した検証だけでなく、ゲーム側にメディア部品への必須ロード参照がないことを確認できた。

### Linux GUI・画像描画：成功

Xorg dummy画面、Mesa llvmpipeによるCPU描画で実施。

```text
GUI RESULT checks=28 failures=0
MEDIA GUI RESULT checks=10 failures=0 captured_frames=32768 rms=0.008703 peak=0.032930 audio_driver=Dummy
```

既存GUIテストは変更せず、マウス・キーボード・日本語・640×480の操作・全編完走を確認。追加GUIテストでは実際の探索選択で背景テクスチャと描画ピクセルが変わること、暗幕・文字色・入力透過、タイトルで実プレイヤーが止まることを確認。

スクリーンショットを目視して本文・応答の読みやすさを確認した：[山道](screenshots/media-mountain.png)、[沢](screenshots/media-stream.png)。仮想ディスプレイのV-Sync切替非対応WARNINGは環境由来。

### 音声信号：成功、スピーカー聴取：未検証

AudioEffectCaptureでGodotミキサー出力の実PCMを取得し、非ゼロのRMSとピークを確認した。上記の値は1回の実測で、取得フレーム数とRMSはタイミングにより変動する。これは命令ログや `playing` フラグだけの確認より一段先の、音声データが生成されていることの検証である。

ただし出力ドライバーはDummy。実スピーカー／ヘッドホンの出音、聴感上の音量・ループ境界・楽曲品質は未検証。音源は接続試験用の短い仮曲であり、完成音楽として評価していない。

### Linux / Web書き出し：成功

固定版4.7.2の公式テンプレートでrelease書き出しが両方成功。JSONをPCKへ含めるinclude_filterを追加した。Linuxの書き出し済み実行ファイルをGUIで起動し、実行エラーなし。

Webはスレッド無効、Chromium＋SwiftShaderで `tests/web_smoke.cjs` を実行。

```json
{"result":"PASS","errors":[],"checkpoint":"ending","rescued":true,"visited":["meadow","stream","ridge"],"persistedAfterReload":true,"backgroundPixelChanged":true,"webAudioRms":0.012816475665259348}
```

ブラウザで3地点→救出→結末、IndexedDB保存、ページ再読込後の再開を確認。UIのない画面端のピクセルが街→山で変わり、WebAudio出力直前のAnalyserNodeで山BGMの非ゼロ波形を確認。ブラウザの実行エラーなし。計測用JSはテスト側だけで挿入し、ゲーム本体にテスト用の外部操作APIを追加していない。ブラウザでも実スピーカー聴取までは行っていない。

## 再実行
READMEの `tests/run.sh` で既存＋追加ヘッドレス試験を実行。表示環境では `tests/gui_tests.gd` と `tests/media_gui_tests.gd`。Web書き出しをHTTP配信し、環境側のPlaywright・Chromiumで `node tests/web_smoke.cjs`。音源は `python3 tools/generate_media_audio.py` で再生成でき、追加Pythonパッケージ不要。

## 計画との差分・残る負債
- 計画した責務・対応表・フォールバックどおり。追加の外部ライブラリや汎用抽象化は不要だった。
- シーンの読み込み自体を省略できるよう、GameUIの必須MediaAdapter preloadを任意シーンのパスへ置き換えた。これが取り外しのための主要な既存コード変更。
- 素材は独自SVG3枚・独自合成WAV2曲。8秒のループ試験曲で、作品全体と同様に公開ライセンスは作者判断。外部素材・生成API依存なし。
- 対応表は起動時読込。実行中のファイル監視・ホットリロードや、プレイヤー交換の自動再配線は未実装。交換後の再起動で反映する。
- 明示対応を採用したため、新イベントはcatalogへの追記が必要。未登録でも物語は動くが、メディアは停止／クリアする。イベント追加時に対応表の到達性テストも更新する。
- 現在のAudioは1曲のみ。クロスフェード、効果音、音量設定UI、立ち絵は対象外。
- 欠落・型違いは検査するが、任意の破損バイナリやGodotのリソースローダー自体の障害を隔離する仕組みではない。
- Firefox/Safari、モバイル、実音声デバイス、長時間の音楽連続再生は未検証。Web全734経路走査は行っていない。文章はMVPの初稿をそのまま維持しており、校正は別工程。

今回の範囲では、既存のイベント通知だけを境界にして独立した音楽・画像を後付けし、省略・別実装への交換も行えることを実証できた。
