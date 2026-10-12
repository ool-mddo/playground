# refocus_topology ユースケース操作手順

`mddo-fw` ネットワークを対象に、実設定から生成したトポロジ (`original_asis`) を
blueprint に基づいて抽象化（土管化 / conduit 化）し、それぞれを emulated 名前空間に変換した上で
必要な snapshot だけをエミュレーション環境として起動する、というユースケース。

## 前提

- `docker compose up -d` 済みであること
- `demo_vars` で `NETWORK_NAME=mddo-fw`, `USECASE_NAME=refocus_topology` になっていること
- blueprint データ (`usecases/refocus_topology/mddo-fw/original_asis_blueprint1/topology.json`) が
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
bash 21_generate_conduit.sh [-b <blueprint_snapshot>]
```

| オプション | 説明 |
|---|---|
| `-b` | 使用する blueprint snapshot 名（省略時: `original_asis_blueprint1`）。`usecases/refocus_topology/mddo-fw/` 配下の blueprint snapshot ディレクトリ名を指定する（例: `original_asis_blueprint2`） |
| `-h` | ヘルプ表示 |

```sh
# 例: site-c を含む blueprint (original_asis_blueprint2) を使って conduit topology を生成
bash 21_generate_conduit.sh -b original_asis_blueprint2
```

blueprint の定義内容に応じて `original_asis`, `original_asis_conduit1`, `original_asis_conduit2`, ...
と、それぞれの名前空間変換後の `emulated_asis`, `emulated_asis_conduit1`, ... が
netoviz index に登録される。結果は以下で確認できる。

```sh
curl -s "http://${API_PROXY}/topologies/index" | jq .
```

netoviz UI（`http://localhost:3000`）からも見える。

conduit topology (`original_asis_conduit*` / `emulated_asis_conduit*`) の生成元 blueprint は、
topology の `ietf-network:networks` 直下 `mddo-topology:networks-attributes` の `flag` に
`blueprint=<blueprint snapshot 名>` として記録される (blueprint が違っても snapshot 名は同じになるため)。
スキーマは [docs/networks_attributes.md](../../docs/networks_attributes.md) を参照。

```sh
curl -s "http://${API_PROXY}/topologies/${NETWORK_NAME}/emulated_asis_conduit1/topology" \
  | jq '."ietf-network:networks"."mddo-topology:networks-attributes"'
# => { "flag": ["blueprint=original_asis_blueprint1"] }
```

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
- blueprint（`usecases/refocus_topology/mddo-fw/original_asis_blueprint1/topology.json`、
  または `-b` で指定した blueprint snapshot）を変更した場合は
  `21_generate_conduit.sh` を再実行してデータを作り直す必要がある
  （`21_generate_conduit.sh` の先頭で該当ネットワークの全 snapshot が一度クリアされる）。

### conduit topology の interface description

conduit topology (layer3) の TP description は、生成した link 構造から再生成される
(`TpDescriptionResolver`)。元トポロジの description は引き継がない。

- 2 endpoint の segment を介した機器 TP: segment を跳ばして `to_<対向ノード>_<対向TP>`
- 3 endpoint 以上の segment の機器 TP / link を持たない TP: 空
- segment TP: `to_<接続先ノード>_<TP>`
- FW cluster pair (`firewall.pair` の primary/secondary): 同名 TP の description は pair で同一にする。link で確定した側の description を、link のない側 (HA 対向ポート) にコピーする
  (original 側: `TpDescriptionResolver`、emulated 側: netomox-exp `NamespaceConverter#sync_firewall_pair_description`)
- `emulated_asis*` は namespace 変換で link から再生成される (netomox-exp `update_tp_description`)。
  2 endpoint の segment は跳ばして対向機器 (`to_<対向ノード>_<対向TP>`、l1_agent 名)、3 endpoint 以上の segment は segment 自身 (`to_Seg-..._EthernetN`)

## 関連ドキュメント

- [usecases/refocus_topology/README.md](../../usecases/refocus_topology/README.md) — blueprint データフォーマット・変換ツールの詳細
- [docs/work/todo/conduit_ospf_area_attributes.md](../../docs/work/todo/conduit_ospf_area_attributes.md) — conduit topology の OSPF area 属性欠落の経緯と対応（対応済み）
- [../../CLAUDE.md](../../CLAUDE.md) — プロジェクト全体のコマンド一覧
