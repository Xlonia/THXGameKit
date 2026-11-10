# THXGameKit

**弾幕ゲーム制作コア**（Godot 4.x アドオン形式）——弾幕の実行ロジック・キャラクター
情報処理・タイムライン・弾幕エディタをコアとして統合し、具体的なゲームプレイ
（自走棋 / STG / RPG / Roguelike）はプラグインとして接続します。

**最初のプラグイン**：[THX75](https://github.com/Xlonia/THX75)
（東方消望紀-無欲拾食紀）——弾幕決闘オートチェス。

> この README は要約です。正式文書（中国語）は [README.md](README.md)、
> 英語版は [README.en.md](README.en.md) を参照してください。

## インストール

THX シリーズのゲームリポジトリは、本コアを **git submodule** として参照します
（ポインタであり実体のコピーではないため、ゲームフォルダの直接コピーには
コアは含まれません）。

```bash
git submodule add https://github.com/Xlonia/THXGameKit addons/thx_gamekit
git clone --recurse-submodules <ゲームリポジトリ>
git submodule update --init
git submodule update --remote addons/thx_gamekit
```

submodule を使わない場合：本リポジトリを ZIP でダウンロードし、ゲームプロジェクトの
`addons/thx_gamekit/` として展開してください（手動更新）。

## 状態

**データ基盤 v0 移植済み**（2026-11-11）：弾幕イベント / 式 / 素材 / タイムライン /
キャラクターテーブル。次の移植ステップ：弾幕エディタとエンティティコア。

## 提供機能（概要）

- **6 種類の弾幕イベント**（通常 / 物理 / 軌道 / 点向 / NodesB / レーザー）、
  種類ごとの公式 CSV テーブル + 旧単一ファイル互換読込
- **式システム**：時間 / 火力点番号 / 集中係数 / ターゲットスナップショット /
  キャラクター照会 / 乱数などほぼ全フィールドに対応、定数畳み込み + C++ 高速評価
  （拡張なしでは内蔵評価器へ自動フォールバック）
- **発射ゲート**：確率(rate)と規律プール(pattern)の二門
- **キャラクターテーブル（狭義のコア）**：キー名 / 日中英名 / 集中・通常速度 /
  火力点配置と割合、スロット結び付け（main/sub/rest）と skill/spell タイムライン
- **タイムライン**（0.1 秒 1 tick、可読な `.gd` テキスト保存）
- **弾幕エディタ**（コアの必須構成要素、試練場プレビュー付き）
- **.thx Mod 形式**：zip（イベント表＋素材）、名前による公式データ上書き

## ライセンス

MIT — [LICENSE](LICENSE) を参照。
