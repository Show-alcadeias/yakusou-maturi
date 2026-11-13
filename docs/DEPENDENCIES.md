# 固定依存関係・導入

調査日：2026-11-14（日本時間）。外部ランタイムライブラリはDMのみ。フォントはデータアセット。テストライブラリ不要。

|依存|固定版|ライセンス|公式情報|
|---|---|---|---|
|Godot Engine|4.7.2 stable（公式 ed1daf0bf）|MIT＋同梱第三者ライセンス|https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable |
|Dialogue Manager|4.2.0 / bbf9d2a5f6a9eaa276310eea8b1379a936239d2e|MIT / addons/dialogue_manager/LICENSE|https://github.com/nathanhoad/godot_dialogue_manager/releases/tag/v4.2.0 |
|日本語フォント|導入時の固定コミットとハッシュを後記|SIL OFL 1.1|https://github.com/google/fonts/tree/main/ofl/notosansjp |

DM公式README（v4.2.0）はGodot 4.6+対応を明記。追加のC#/.NET環境は不要。

## 再導入
1. Godot公式リリースのLinux x86_64 zipと `SHA512-SUMS.txt` を取得して照合し展開。
2. DMのmainではなく `v4.2.0` タグの公式アーカイブを取得し、`addons/dialogue_manager` だけをプロジェクトへコピー。アーカイブ内のLICENSEを保持。プラグインのソース改変はしない。
3. project.godotのeditor_pluginsで有効化し、公式DM Autoloadを登録。初回は `godot --headless --editor --path . --quit` でインポート。
4. バージョン更新はこの文書、テスト結果、レビューを同時に更新して行う。

参照した構文・API：
- https://github.com/nathanhoad/godot_dialogue_manager/blob/v4.2.0/docs/Conditions_Mutations.md
- https://github.com/nathanhoad/godot_dialogue_manager/blob/v4.2.0/docs/Using_Dialogue.md
- https://github.com/nathanhoad/godot_dialogue_manager/blob/v4.2.0/docs/API.md

Godot zip SHA512：`9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`

フォント固定元：google/fonts コミット `66a36c8c94b1a5d992ee4e7f392fccfe4945767c`、`ofl/notosansjp/NotoSansJP[wght].ttf`。同梱名 `assets/fonts/NotoSansJP.ttf`。ライセンスは同ディレクトリのOFL.txt。
フォントSHA256：`c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`

エクスポートテンプレートもGodot 4.7.2公式配布に固定し、同リリースのSHA512と照合済み。Linux x86_64とWebスレッド無効版を使用。GodotのMIT本文および第三者ライセンス：https://godotengine.org/license/ 、https://godotengine.org/license/third-party/ 。ゲーム固有コード・シナリオ全体の公開ライセンスは作者判断とし、新たに付与しない。
