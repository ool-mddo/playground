# CLAUDE.md

## プロジェクト概要

**ool-mddo/playground** はネットワーク・デジタルツイン (NDT) の統合実行環境。
実際の ISP/企業ネットワーク機器の設定ファイルからマルチレイヤートポロジモデルを自動抽出し、
候補トポロジ変更をエミュレーション環境で検証する。

複数の Docker コンテナ (microservices) が REST API で連携し、全体の処理フローはシェルスクリプトで制御される。

詳細なアーキテクチャは [docs/architecture.md](docs/architecture.md) を参照。

## 現在のターゲット

- **デモ:** `demo/candidate_model_ops/`
- **ユースケース:** `refocus_topology`
- **ネットワーク設定:** `configs/mddo-fw/` (Juniper SRX FW HA クラスタ)
- **ユースケース設定:** `usecases/refocus_topology/mddo-fw/params.yaml`

## 重要な制約

- **変更しないディレクトリ:** `queries/`, `topologies/`, `policies/` は自動生成。直接編集不可。
- **`configs/mddo-fw` はサブモジュール:** 変更は submodule 側でコミットしてから、playground 側で参照先を更新すること。
- **`demo_vars` が全体の設定起点:** `NETWORK_NAME` / `USECASE_NAME` を変えると対象ネットワーク・ユースケースが切り替わる。

## サービス構成 (抜粋)

| サービス | ポート | 役割 |
|---|---|---|
| `api-proxy` (nginx) | 15000 | 全 API のエントリポイント |
| `model-conductor` | (内部) | トポロジ生成オーケストレーター |
| `netomox-exp` | (内部) | トポロジモデル保存・変換・ユースケースロジック |
| `batfish-wrapper` + `batfish` | (内部) | 機器設定解析 |
| `firewall-policy-parser` | (内部) | Juniper FW 設定解析 → トポロジへのマージ |
| `ansible-eda` | 48080 | ContainerLab デプロイの自動化 (webhook) |
| `netoviz` | 3000 | トポロジ可視化フロントエンド |

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

# refocus_topology ユースケース (トポロジ生成 + conduit topology 生成 + netoviz 更新)
./21_refocus_topology.sh

# 候補モデル生成 + エミュレーション評価 (フルフロー)
./00_run_phase.sh
```

`21_refocus_topology.sh` の処理順序:
1. `generate_original_asis_topology` — Batfish でトポロジ生成
2. `splice_external_as_topology` — 外部 AS トポロジをマージ
3. `splice_firewall_attributes` — FW 属性をマージ
4. netoviz index に `original_asis` エントリを登録
5. `generate_conduit_topology` — blueprint に基づいた土管化トポロジ生成 (`original_asis_conduit*`) + netoviz index 追記
6. `convert_namespace "original_asis"` — 名前空間変換: `original_asis` → `emulated_asis` + netoviz index 追記
7. conduit snapshot ごとに `convert_namespace` — `original_asis_conduit*` → `emulated_asis_conduit*` + netoviz index 追記

`convert_namespace` は内部で `POST /topologies/:nw/:ss/ns_convert_table` を呼び出し、
変換テーブルを各スナップショットディレクトリ (`topologies/<nw>/<ss>/ns_convert_table.json`) に保存する。

> **blueprint ファイル:** `usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology.json`
> を人が作成・配置することで conduit 処理の抽象化目標を定義する。

> **FW ノードアトリビュート JSON スキーマ:** 複数リポジトリをまたがる canonical definition は
> [docs/firewall_node_attributes.md](docs/firewall_node_attributes.md) を参照。

## ライブ開発

`repos/{service}/` を編集するとコンテナ内に即時反映される (Docker bind mount)。
イメージの再ビルド・再起動は不要。
