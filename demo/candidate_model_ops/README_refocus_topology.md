# refocus_topology ユースケース操作手順

`mddo-fw` ネットワークを対象に、実設定から生成したトポロジ (`original_asis`) を
blueprint に基づいて抽象化（土管化 / conduit 化）し、それぞれを emulated 名前空間に変換した上で
必要な snapshot だけをエミュレーション環境として起動する、というユースケース。

## 前提

- `docker compose up -d` 済みであること
- `demo_vars` で `NETWORK_NAME=mddo-fw`, `USECASE_NAME=refocus_topology` になっていること
- blueprint データ (`usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology.json`) が
  配置されていること。フォーマット・作り方は [usecases/refocus_topology/README.md](../../usecases/refocus_topology/README.md) を参照

## スクリプト構成

```
21_generate_conduit.sh ... トポロジ生成 (original_asis) → 外部AS/FW属性マージ
                            → conduit topology 生成 (blueprint 基準)
                            → namespace 変換 (original_* → emulated_*)
                            → netoviz index 登録
                            環境起動は含まない
22_up_conduit.sh ......... 21 で生成・登録済みの snapshot のうち、指定した1つを
                            emulated 環境として起動する (up_emulated_env)
```

## 使い方

### 1. トポロジ生成 (`21_generate_conduit.sh`)

```sh
cd demo/candidate_model_ops
source demo_vars
bash 21_generate_conduit.sh
```

blueprint の定義内容に応じて `original_asis`, `original_asis_conduit1`, `original_asis_conduit2`, ...
と、それぞれの名前空間変換後の `emulated_asis`, `emulated_asis_conduit1`, ... が
netoviz index に登録される。結果は以下で確認できる。

```sh
curl -s "http://${API_PROXY}/topologies/index" | jq .
```

netoviz UI（`http://localhost:3000`）からも見える。

### 2. emulated 環境の起動 (`22_up_conduit.sh`)

```sh
bash 22_up_conduit.sh -s <snapshot_name> [-d]
```

| オプション | 説明 |
|---|---|
| `-s` | 起動したい snapshot 名（**必須**）。netoviz index に登録済みの emulated 側の名前を指定する（例: `emulated_asis`, `emulated_asis_conduit1`） |
| `-d` | debug モード。containerlab を使わない（後述） |
| `-h` | ヘルプ表示 |

`-s` を省略した場合、または netoviz index に未登録の名前を指定した場合はエラーで即終了する
（先に `21_generate_conduit.sh` を実行するよう促すメッセージが出る）。

```sh
# 例: emulated_asis を、containerlab を使わずに起動（config生成テンプレートの動作確認のみ）
bash 22_up_conduit.sh -s emulated_asis -d
```

## 注意事項

- `22_up_conduit.sh` は**一度に1つの snapshot しか起動しない**。conduit の複数 snapshot を
  まとめて起動する機能は現状ない（別途対応予定）。
- `-d` を付けても、ansible-eda への config 生成・api-proxy へのアップロードの POST 自体は実行される。
  スキップされるのは containerlab へのデプロイ（`deploy containerlab`）と iperf セットアップ、
  および環境起動後の状態計測・環境破棄（`env_post_clean.sh`）のみ。
- `-d` なし（`WITH_CLAB=true`）の場合は実際に worker 上へ containerlab 環境をデプロイする。
  この場合、worker 側の `node_exporter`（`WORKER_ADDRESS:9100`）が起動していないと
  `scripts/up_emulated_env.sh` 内のジョブ完了待ちループ（`AllJob_Complete` ポーリング）が
  無限ループする点に注意（タイムアウト等のガードは現状ない）。
- **既知の不具合**: conduit snapshot（`original_asis_conduitX` / `emulated_asis_conduitX`）には
  conduit topology 生成時に OSPF area のネットワーク属性（`identifier` 等）が欠落する問題があり、
  `-d` を付けても ansible-eda 側の "generate ospf config" タスクで失敗する場合がある。
  詳細・原因・対応方針は [docs/todo_conduit_ospf_area_attributes.md](../../docs/todo_conduit_ospf_area_attributes.md)
  を参照。この問題が解消するまで conduit snapshot の起動確認は完走しない
  （`original_asis`／`emulated_asis` 本体には影響なし）。
- blueprint（`usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology.json`）を
  変更した場合は `21_generate_conduit.sh` を再実行してデータを作り直す必要がある
  （`21_generate_conduit.sh` の先頭で該当ネットワークの全 snapshot が一度クリアされる）。

## 関連ドキュメント

- [usecases/refocus_topology/README.md](../../usecases/refocus_topology/README.md) — blueprint データフォーマット・変換ツールの詳細
- [docs/todo_conduit_ospf_area_attributes.md](../../docs/todo_conduit_ospf_area_attributes.md) — 既知の不具合（conduit topology の OSPF area 属性欠落）
- [../../CLAUDE.md](../../CLAUDE.md) — プロジェクト全体のコマンド一覧
