# 環境準備

環境設定については[デモ環境構築](../../../../doc/provision.md)を参照してください。

- `playground` リポジトリのタグは `v1.7.1` を選択してください
- デモシステムを起動してください ( `docker compose up` )

> [!NOTE]
> PNIユースケースはセグメント移転ユースケースのシナリオを拡張する形で構築されています。
> - セグメント移転ユースケースの[環境構築](../move_seg/provision.md)についても参照してください。
> - Step1,2 などの手順は共通です。(PNIユースケースはいまのところ step1-2 までの実装です。まだ step3-4 については対応できていません)

PNIユースケースでは、ネットワーク = mddo-bgp, スナップショット = original_asis, emulated_asis がベースになります。

- 実際のコンフィグ類: `playground/configs/mddo-bgp`
- コンフィグリポジトリ: [ool-mddo/mddo-bgp](https://github.com/ool-mddo/mddo-bgp)

## デモ準備

### デモ作業ディレクトリ

デモディレクトリへ移動します。

```bash
cd playground/demo/copy_to_emulated_env/
```

以降の作業はこのディレクトリが起点になります。ユースケース別/一部ユースケース共通のデータ・スクリプト等のディレクトリ配下のようになっています。
* copy_to_emulated_env
  * project/playbooks
    * (seg_move): 固有のデータ等は特にありません
    * pni : pni ユースケース共通
    * pni_te : pni_te ユースケース固有のデータ・スクリプト
    * pni_addlink : pni_addlink ユースケース固有のデータ・スクリプト

### Grafana(トラフィックの可視化)

デモ用のGrafanaを起動します。

```bash
# playground/demo/copy_to_emulated_env
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

### トラフィック可視化ツール(Grafana)画面の準備

次(以降)のステップで、仮想環境内でのトラフィック生成や経路制御を行います。トラフィック流量を可視化するためにGrafanaを使用するため、先に準備しておきます。(grafanaの設定については `copy_to_emulated_env/visualize/grafana/grafana.ini` を参照してください)

`http://localhost:23000` にアクセス

- user: `admin`
- pass: `mddo`

![grafana login](fig/grafana_login.png)

ハンバーガーメニューから [Dashboards]

![grafana dashboard 1](fig/grafana_dashboard1.png)

[General] - [ool-mddo]

![grafana dashboard 2](fig/grafana_dashboard2.png)

最初は生成されるトラフィックを確認するため、endpoint01-iperf[1-4] を選択しておきます。

![grafana node selection](fig/grafana_select_node.png)

表示時間(”Last N minultes”)・データ更新間隔は適宜設定してください。

![grafana update interval](fig/grafana_interval.png)

### 入力データ(NW機器コンフィグ)

インプットになる(NW機器コンフィグ)を確認します。

```bash
ls playground/configs/mddo-bgp/original_asis/configs/
```
```
playground/demo/copy_to_emulated_env$ ls ~/playground/configs/mddo-bgp/original_asis/configs/
Core-TK01  Core-TK02  Edge-TK01  Edge-TK02  Edge-TK03  SW-TK01
```

### 入力データ(物理トポロジデータ)

コンフィグファイルから物理(L1)トポロジデータを生成して用意しておく必要がありますが、ここでは割愛します。

- [物理トポロジデータの生成](../../../layer1_topology/doc/operation.md) を参照してください
- 物理トポロジデータは `playground/configs/mddo-bgp/original_asis/batfish/layer1_topology.json` です


### (optional) トラフィックの再生成・環境再起動

pni ユースケースでは指定されたフローデータをもとにトラフィックを生成します (step2-2)。トラフィックデータ (flowdata.csv) のデータを差し替えたあと、環境を再起動して emulated env で付加するトラフィックを変えることができます。(実行前にユースケースディレクトリにある flowdata.csv をさしかえてください。)

```bash
# in copy_to_emulated_env dir

# データの差替(例)
# cp project/playbooks/pni_te/before_flowdata.csv project/playbooks/pni_te/flowdata.csv

# 再起動
./demo_step2-2.sh -r
```
