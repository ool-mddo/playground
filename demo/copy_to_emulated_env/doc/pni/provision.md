# 環境準備

環境設定については[デモ環境構築](../../../../doc/provision.md)を参照してください。

- `playground` リポジトリのタグは `v1.5.2` を選択してください
- デモシステムを起動してください ( `docker compose up` )

PNIユースケースでは、ネットワーク = biglobe_deform, スナップショット = original_asis, emulated_asis がベースになります。

- 実際のコンフィグ類: `playground/configs/biglobe_deform`
- コンフィグリポジトリ: [ool-mddo/biglobe_deform](https://github.com/ool-mddo/biglobe_deform)

## デモ準備

### デモ作業ディレクトリ

デモディレクトリへ移動します。

```bash
cd playground/demo/copy_to_emulated_env/
```

### Grafana(トラフィックの可視化)

デモ用のGrafanaを起動します。

```bash
# playground/demo/copy_to_emulated_env/visualize
cd visualize
docker compose up -d
```

Grafanaが起動したことを確認します。

```bash
docker compose ps
```

```
playground/demo/copy_to_emulated_env/visualize$ docker compose ps
NAME                IMAGE                             COMMAND                  SERVICE             CREATED             STATUS                PORTS
cadvisor            gcr.io/cadvisor/cadvisor:latest   "/usr/bin/cadvisor -…"   cadvisor            8 days ago          Up 8 days (healthy)   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp
grafana             grafana/grafana-oss:latest        "/run.sh"                grafana             8 days ago          Up 8 days             0.0.0.0:23000->3000/tcp, :::23000->3000/tcp
prometheus          prom/prometheus:latest            "/bin/prometheus --c…"   prometheus          8 days ago          Up 8 days             0.0.0.0:9090->9090/tcp, :::9090->9090/tcp
redis               redis:latest                      "docker-entrypoint.s…"   redis               8 days ago          Up 8 days             6379/tcp
```

### 入力データ(NW機器コンフィグ)

インプットになる(NW機器コンフィグ)を確認します。

```bash
ls ~/playground/configs/biglobe_deform/original_asis/configs/
```

```
playground/demo/copy_to_emulated_env$ ls ~/playground/configs/biglobe_deform/original_asis/configs/
Core-TK01  Core-TK02  Edge-TK01  Edge-TK02  Edge-TK03  SW-TK01
```

### 入力データ(物理トポロジデータ)

コンフィグファイルから物理(L1)トポロジデータを生成して用意しておく必要がありますが、ここでは割愛します。

- [物理トポロジデータの生成](../../../layer1_topology/doc/operation.md) を参照してください
- 物理トポロジデータは `playground/configs/biglobe_deform/original_asis/batfish/layer1_topology.json` です

### デモ環境変数

デモ用パラメタを設定します。(ファイルは `demo_vars`)

デモでは以下の値(デモ環境で使用する変数)を設定する必要があります。

- 仮想環境(emulate env)構築のためのデータ
    - `LOCALSERVER_USER` : 環境構築の際、ansible で localhost にsshして操作しているため、そこで使用するユーザ名を指定
- デモ全体で使用するパラメータ
    - `NETORK_NAME` : 対象となるネットワークの名前 ([Batfishのデータ管理とネーミングの制約](https://github.com/ool-mddo/playground/blob/main/doc/system_architecture.md#%E3%83%8D%E3%83%BC%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%AE%E5%88%B6%E7%B4%84) を参照してください)
- デモの一部ステップ(step2.5)で使用するデータ…優先してトラフィックを流すeBGP peerの指定
    - `PREFERRED_NODE` , `PREFERRED_INTERFACE` , `EXTERNAL_ASN` : step2.5 で解説します。
        - step2.5以降で使用する変数なのでそこまでは未設定でも問題ありません

```bash
ANSIBLERUNNER_IMAGE="ghcr.io/ool-mddo/mddo-ansible-runner:v3.0.0"
API_PROXY="localhost:15000"
API_BRIDGE="playground_default"
LOCALSERVER_USER=mddo
PLAYGROUND_DIR="/home/${LOCALSERVER_USER}/playground"
ANSIBLE_RUNNER_DIR="${PLAYGROUND_DIR}/demo/copy_to_emulated_env"

# all steps: target network name
NETWORK_NAME="biglobe_deform"
NETWORK_INDEX="${NETWORK_NAME}_index.json"

# step2.5, preffered peer parameter (use original_asis node/interface name)
PREFERRED_NODE="edge-tk01"
PREFERRED_INTERFACE="ge-0/0/3.0"
EXTERNAL_ASN=65550
```
