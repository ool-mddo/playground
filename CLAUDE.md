# CLAUDE.md

## プロジェクト概要

**ool-mddo/playground** はネットワーク・デジタルツイン (NDT) の統合実行環境。
実際の ISP/企業ネットワーク機器の設定ファイルからマルチレイヤートポロジモデルを自動抽出し、
候補トポロジ変更をエミュレーション環境で検証する。

複数の Docker コンテナ (microservices) が REST API で連携し、全体の処理フローはシェルスクリプトで制御される。

詳細なアーキテクチャは [docs/architecture.md](docs/architecture.md) を参照。

`docs/` 直下と `docs/design_notes/` は現行仕様・設計の記述用。
作業メモ (plan / 調査 / todo) は `docs/work/{plans,investigations,todo}/` に置く (ファイル名に `plan_` 等の接頭辞は付けない)。
`docs/` の文書は先頭に YAML front matter (`topic` / `type` / `status` / `related`) を付け、
新規作成・状態変更時は [docs/README.md](docs/README.md) の索引も更新する (書式と運用は同ファイル参照)。

## コミット前のドキュメント更新チェック

`git commit` の前に、次を確認する (`.claude/hooks/docs-check.sh` が、同じステージ内容につき 1 回だけコミットをブロックして促す)。

1. 変更に関連する `docs/` の文書の `status` と本文の状態記述 (「未コミット」「未実施」など) が、今回の変更と食い違っていないか。
2. 新規・変更した `docs/` の文書に front matter があり、[docs/README.md](docs/README.md) の索引に載っているか。
3. この CLAUDE.md や README などの入口文書 (サービス構成・コマンド・制約) に影響する変更がないか。

## 現在のターゲット

- **デモ:** `demo/candidate_model_ops/`
- **ユースケース:** `refocus_topology`
- **ネットワーク設定:** `configs/mddo-fw/` (Juniper SRX FW HA クラスタ)
- **ユースケース設定:** `usecases/refocus_topology/mddo-fw/params.yaml`

## 重要な制約

- **変更しないディレクトリ:** `queries/`, `topologies/`, `policies/` は自動生成。直接編集不可。
- **`states/` は自動生成:** state-conductor の出力先 (`.gitignore` 済み)。直接編集不可。
- **`profiles/` は人が書く:** netoviz2 の schematic レイアウト用のダイアグラムプロファイル (正本)。置き場所と使い方は [profiles/README.md](profiles/README.md)、書式は [repos/netoviz2/docs/design/profile_format.md](repos/netoviz2/docs/design/profile_format.md)。
- **`configs/mddo-fw` はサブモジュール:** 変更は submodule 側でコミットしてから、playground 側で参照先を更新すること。
- **`repos/` 下のサブモジュールのブランチ名にスラッシュを使わない:** CI はブランチ名をそのままコンテナイメージのタグにする (`ghcr.io/ool-mddo/<service>:<ブランチ名>`)。例: `feature/xxx` ではなく `v1.22.0-dev`。詳細は [docs/design_notes/development.md](docs/design_notes/development.md)。
- **`demo_vars` が全体の設定起点:** `NETWORK_NAME` / `USECASE_NAME` を変えると対象ネットワーク・ユースケースが切り替わる。

## サービス構成 (抜粋)

| サービス | ポート | 役割 |
|---|---|---|
| `api-proxy` (nginx) | 15000 | 全 API のエントリポイント |
| `model-conductor` | (内部) | トポロジ生成オーケストレーター |
| `netomox-exp` | (内部) | トポロジモデル保存・変換・ユースケースロジック |
| `batfish-wrapper` + `batfish` | (内部) | 機器設定解析 |
| `firewall-policy-parser` | (内部) | Juniper FW 設定解析 → トポロジへのマージ |
| `state-conductor` | (内部) | emulated 環境のトラフィック計測・state 管理 (可視化込み起動時のみ。出力は `./states` に永続化) |
| `ansible-eda` | 48080 | ContainerLab デプロイの自動化 (webhook) |
| `netoviz2` | (api-proxy 経由: `/netoviz2/`) | 汎用トポロジビューワー (静的 SPA。データは netomox-exp の API)。`repos/netoviz2`、ドキュメントは [repos/netoviz2/docs/](repos/netoviz2/docs/README.md) |

旧 `netoviz` は compose から削除済み (`repos/netoviz` は残置)。

## 起動コマンド

```bash
# 全サービス起動
docker compose up -d

# 可視化込み (grafana, prometheus, state-conductor 追加)
docker compose -f docker-compose.yaml -f docker-compose.visualize.yaml up -d

# サブモジュール状態確認
./check_repos.sh
```

## デモ実行 (refocus_topology)

```bash
cd demo/candidate_model_ops
source demo_vars

# refocus_topology ユースケース: トポロジ生成 + conduit topology 生成 + namespace変換 + netoviz 更新
./21_generate_conduit.sh

# 上で生成・登録済みの snapshot のうち1つだけをエミュレーション環境として起動
./22_up_conduit.sh -s emulated_asis -d   # -d: containerlab を使わない (config生成確認のみ)

# 起動中の emulated 環境の FW (vSRX) に障害を注入 / 復旧 (-u)
./23_fw_fault.sh -s emulated_asis -n site-a-fw-1 -i ge-0/0/1,ge-0/0/2
./23_fw_fault.sh -s emulated_asis -n site-a-fw-1 -i ge-0/0/1,ge-0/0/2 -u

# 候補モデル生成 + エミュレーション評価 (フルフロー、別シナリオ)
./00_run_phase.sh
```

`21_generate_conduit.sh` の処理順序:
1. `generate_original_asis_topology` — Batfish でトポロジ生成
2. `splice_external_as_topology` — 外部 AS トポロジをマージ
3. `splice_firewall_attributes` — FW 属性をマージ
4. netoviz index に `original_asis` エントリを登録
5. `generate_conduit_topology` — blueprint (`-b` で指定) に基づく土管化トポロジ生成 (`original_asis_conduit*`)
6. `convert_namespace` — 名前空間変換: `original_asis` → `emulated_asis`
7. conduit snapshot ごとに `convert_namespace` — `original_asis_conduit*` → `emulated_asis_conduit*`

(5〜7 は、生成・変換した snapshot を netoviz index にも追記する)

環境起動は含まない（`22_up_conduit.sh` が別スクリプトとして担当）。詳細な操作手順・注意事項は
[demo/candidate_model_ops/README_refocus_topology.md](demo/candidate_model_ops/README_refocus_topology.md) を参照。

`convert_namespace` (`ns_convert` API) は、変換テーブルを `topologies/<nw>/<ss>/ns_convert_table.json` に、
同一内容で original / emulated の両 snapshot に保存する (作成時のみペアで扱い、snapshot 単体の DELETE は相手側を削除しない)。

> **blueprint ファイル:** `usecases/refocus_topology/mddo-fw/original_asis_blueprint1/topology.json`
> を人が作成・配置することで conduit 処理の抽象化目標を定義する。`21_generate_conduit.sh -b` で切り替える
> (デフォルト: `original_asis_blueprint1`)。

複数リポジトリをまたがる JSON スキーマの canonical definition:

- FW ノードアトリビュート: [docs/firewall_node_attributes.md](docs/firewall_node_attributes.md)
- FHRP (VRRP/HSRP) の layer3 TP アトリビュート `fhrp`: [docs/fhrp_termination_point_attributes.md](docs/fhrp_termination_point_attributes.md)
- networks アトリビュート (conduit の生成元 blueprint。`ietf-network:networks` 直下の `mddo-topology:networks-attributes`): [docs/networks_attributes.md](docs/networks_attributes.md)

## ライブ開発

`repos/{service}/` を編集するとコンテナ内に即時反映される (Docker bind mount)。
イメージの再ビルド・再起動は不要。

**netomox (gem) の修正を伴う場合**は、`docker-compose.override.yaml` でローカルの netomox を netomox-exp / model-conductor のコンテナに
bind mount して開発する (gem の中身は通常の bind mount の対象外)。手順・注意点・公開までの流れは
[docs/design_notes/development.md](docs/design_notes/development.md#netomox-gem-の修正を伴う開発) を参照。
