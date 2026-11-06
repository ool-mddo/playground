# netoviz2 / schematic のドキュメント整理

状態: **実施済み (netoviz2 側・playground 側とも未コミット)。H1 = playground に残す、H2 = CLAUDE.md は短い入口にして `@docs/agent_guide.md` を取り込む、で承認済み。**

実施結果: netoviz2 の `docs/` を新設 (architecture.md、development.md、agent_guide.md、design/{layout,schematic_layout,profile_format}.md、work/plans/{requirements,schematic_layout}.md、README.md)、README.md を公開用に書き直し、CLAUDE.md を短い入口にした。playground 側は、移動した 3 文書を削除し、`profiles/README.md` を案内に変え、`docs/design_notes/development.md` の netoviz2 の節を縮め、CLAUDE.md と `docs/netoviz2_data_format.md` のリンクを更新した。
注意: netoviz2 の文書からの playground の文書 (`netoviz2_data_format.md`、`profiles/`) へのリンクは、GitHub の `main` ブランチの URL。playground の `main` には、まだ両方とも無い (開発ブランチ `v2.12.1-dev-netoviz2` にある)。playground のリリースで `main` に入った時点で有効になる。

## 1. 目的

- netoviz2 に関するドキュメントを、リポジトリ `repos/netoviz2` の `docs/` に集める (リポジトリ単体で完結させる)。
- `README.md` は、第三者向けの公開用にする (紹介・概要・機能・使い方)。開発のためのルール (AI エージェント向けを含む) は `docs/` に移す。
- `docs/` に、netoviz2 の構成・アーキテクチャのドキュメントを新しく作る。
- schematic レイアウト (これまでの検討) の文書を整理する。

## 2. 現状

| 場所 | 内容 | 行数 |
|---|---|---|
| `repos/netoviz2/README.md` | 紹介、開発手順、動作確認 3 通り、構成、機能、CI、ライセンス、テーマが混在 | 122 |
| `repos/netoviz2/CLAUDE.md` | AI エージェント向けの方針、動作確認、コマンド | 26 |
| `docs/netoviz2_data_format.md` | データ形式・API 仕様 (netomox-exp が実装、netoviz2 が利用) | 342 |
| `docs/design_notes/netoviz2_layout.md` | レイアウトの設計と検討の経緯 (3.3.1 が schematic) | 143 |
| `docs/design_notes/development.md` の「netoviz2 の開発」 | 開発サーバ・コンテナ・動作確認のヒント (README と重複) | 約 40 |
| `docs/work/plans/netoviz2_requirements.md` | 要求・設計・実装計画 (経緯と進捗。一部は古い) | 439 |
| `docs/work/plans/netoviz2_schematic_layout.md` | schematic の計画・判断・進捗の履歴 | 514 |
| `profiles/README.md` | プロファイルの書式 | 49 |
| `nv2-work/` (削除済み) | 引き継ぎ前の検討資料 (設計案 DESIGN.md、CONTEXT.md、参考資料)。取り込み後に削除した | — |

## 3. 整理後の構成

### repos/netoviz2 (独立リポジトリ。公開)

```
README.md                    公開用: 紹介・概要・機能・使い方 (起動、URL、操作)・ライセンス。開発者向けは docs/ へ
CLAUDE.md                    AI エージェント向けの入口 (短く。docs/agent_guide.md を取り込む)
docs/
  README.md                  目次
  architecture.md            (新規) 構成・アーキテクチャ
  development.md             開発手順 (開発サーバ、動作確認 3 通り、コンテナ、CI、ブランチ名、ブラウザでの確認のヒント)
  agent_guide.md             AI エージェント向けの開発ルール (CLAUDE.md の方針の本体)
  design/
    layout.md                レイアウトの設計と検討の経緯 (playground の design_notes/netoviz2_layout.md から。schematic の節は分ける)
    schematic_layout.md      schematic レイアウトの現行設計 (配置の流れ、推論、継承、経路、設計原則)
    profile_format.md        ダイアグラムプロファイルの書式 (playground の profiles/README.md から)
  work/plans/
    requirements.md          要求・設計・実装計画 (playground の work/plans/netoviz2_requirements.md から。経緯の記録)
    schematic_layout.md      schematic の計画・判断・進捗の履歴 (同 netoviz2_schematic_layout.md から)
```

### playground

- 移動したファイルは削除する (`netoviz2_layout.md`、`netoviz2_requirements.md`、`netoviz2_schematic_layout.md`)。
- `profiles/README.md` は、短い案内に変える (正本の置き場所と、書式は netoviz2/docs/design/profile_format.md を参照)。
- `docs/design_notes/development.md` の「netoviz2 の開発」は、要点と netoviz2/docs/development.md へのリンクに縮める。
- `CLAUDE.md` / `docs/architecture.md` のリンクと説明を更新する。
- `nv2-work/` は触らない (git 管理外の検討資料)。設計案 (DESIGN.md) の設計原則は、`design/schematic_layout.md` に、自分の言葉でまとめて取り込む。参考資料 (書籍のテキストや図) は、公開リポジトリに入れない。

## 4. 承認が必要な判断

### H1: データ形式・API 仕様 (`netoviz2_data_format.md`) の置き場所 (推奨: playground に残す)

- 仕様は、netomox-exp (実装) と netoviz2 (利用) の両方が従う。playground の規約では、複数リポジトリにまたがる canonical definition は playground の `docs/` に置く (`firewall_node_attributes.md` など)。
- 推奨: **playground に残す**。netoviz2 の docs からは、GitHub の URL でリンクする。netomox-exp のコードやコメントの参照は、そのまま。
- 代替: netoviz2 の docs に移す。netomox-exp の CLAUDE.md とコードのコメント (5 か所) の参照先を直す。

### H2: `CLAUDE.md` の扱い (推奨: 短い入口として残し、本体は docs に)

- `CLAUDE.md` は Claude Code が自動で読む。無くすと、ルールが読まれなくなる。
- 推奨: `CLAUDE.md` は数行にして、`@docs/agent_guide.md` で本体を取り込む。ルールの本文は `docs/agent_guide.md` に置く。

### その他 (確認だけ。異論があれば指摘してください)

- README は日本語のまま (組織の言語に合わせる)。英語版が必要なら別途。
- `work/plans/` の 2 つの文書は、経緯の記録として、内容は変えずに移す (冒頭に「経緯の記録。現行の仕様は design/ を参照」と注記)。古い記述 (「2 つのエンジン」など) は、注記で補う。
- コミットは、netoviz2 は docs の整理を 1 コミット (コード変更とは分ける)。playground は、ご指示があるまでコミットしない。

## 5. 作業ステップ

| # | 内容 |
|---|---|
| 1 | netoviz2 のコードを読んで事実を確認し、`docs/architecture.md` を作る (構成、データの流れ、状態管理、描画、レイアウトエンジン、schematic のパイプライン、経路、配信・CI、テスト) |
| 2 | `docs/development.md`、`docs/agent_guide.md` を作り、README と CLAUDE.md から移す |
| 3 | `README.md` を公開用に書き直す |
| 4 | `docs/design/{layout,schematic_layout,profile_format}.md` を作る (playground の既存文書と nv2-work の設計案から) |
| 5 | `docs/work/plans/` に経緯の文書を移す (注記つき) |
| 6 | `docs/README.md` (目次) を作り、リンクを検証する |
| 7 | playground 側の削除・案内・リンクの更新 (H1 の結果に従う) |
| 8 | リンク切れの検証 (相対リンク、GitHub URL)。netoviz2 の 4 コマンド (prettier, typecheck, test, lint, build) |
