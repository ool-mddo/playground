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

# refocus_topology ユースケース (トポロジ生成 + netoviz 更新)
./21_refocus_topology.sh

# 候補モデル生成 + エミュレーション評価 (フルフロー)
./00_run_phase.sh
```

## ライブ開発

`repos/{service}/` を編集するとコンテナ内に即時反映される (Docker bind mount)。
イメージの再ビルド・再起動は不要。
