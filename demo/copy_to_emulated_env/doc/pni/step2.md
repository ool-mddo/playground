# Step2
Step2は2つのオペレーションに分割しています。

> [!NOTE]
> セグメント移転ユースケースから拡張をしています。step2-1はセグメント移転ユースケースと共通、step2-2はPNIユースケース用の拡張です。

## Step2-1: **As-Is 仮想環境作成**

現状 (original_asis) トポロジデータを仮想環境用のデータ (emulated_asis) に変換します。また、emulated_asis トポロジデータをもとに仮想環境 (emulated env.) を起動します。

```bash
./demo_step2-1.sh
```

仮想環境が起動したことを確認します。

```bash
sudo clab inspect --all
```

```
playground/demo/copy_to_emulated_env$ sudo clab inspect --all
+----+---------------------+----------+---------------------------------+--------------+---------------------------------+--------------+---------+-----------------+-----------------------+
| #  |      Topo Path      | Lab Name |              Name               | Container ID |              Image              |     Kind     |  State  |  IPv4 Address   |     IPv6 Address      |
+----+---------------------+----------+---------------------------------+--------------+---------------------------------+--------------+---------+-----------------+-----------------------+
|  1 | clab/clab-topo.yaml | emulated | clab-emulated-PNI01             | 607bbb36f236 | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.9/24  | 2001:172:20:20::9/64  |
|  2 |                     |          | clab-emulated-POI-East          | 02e8f860c825 | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.14/24 | 2001:172:20:20::e/64  |
|  3 |                     |          | clab-emulated-core-tk01         | c35c381b0380 | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.11/24 | 2001:172:20:20::b/64  |
|  4 |                     |          | clab-emulated-core-tk02         | 4bb229fdbf6b | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.6/24  | 2001:172:20:20::6/64  |
|  5 |                     |          | clab-emulated-edge-tk01         | 57e294963247 | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.13/24 | 2001:172:20:20::d/64  |
|  6 |                     |          | clab-emulated-edge-tk02         | fcb4c875dc1b | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.10/24 | 2001:172:20:20::a/64  |
|  7 |                     |          | clab-emulated-edge-tk03         | dfccda9c0765 | crpd:22.1R1.10                  | juniper_crpd | running | 172.20.20.4/24  | 2001:172:20:20::4/64  |
|  8 |                     |          | clab-emulated-endpoint01-iperf1 | 1f64c2de7944 | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.3/24  | 2001:172:20:20::3/64  |
|  9 |                     |          | clab-emulated-endpoint01-iperf2 | d41f10eeb405 | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.7/24  | 2001:172:20:20::7/64  |
| 10 |                     |          | clab-emulated-endpoint01-iperf3 | 38d73375aacf | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.8/24  | 2001:172:20:20::8/64  |
| 11 |                     |          | clab-emulated-endpoint01-iperf4 | 30d9b4b88d4a | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.12/24 | 2001:172:20:20::c/64  |
| 12 |                     |          | clab-emulated-endpoint02-iperf1 | 8e22481205de | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.2/24  | 2001:172:20:20::2/64  |
| 13 |                     |          | clab-emulated-endpoint02-iperf2 | 3f054184a698 | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.16/24 | 2001:172:20:20::10/64 |
| 14 |                     |          | clab-emulated-endpoint02-iperf3 | a2d695ffdb64 | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.15/24 | 2001:172:20:20::f/64  |
| 15 |                     |          | clab-emulated-endpoint02-iperf4 | 313b5477a726 | ghcr.io/ool-mddo/ool-iperf:main | linux        | running | 172.20.20.5/24  | 2001:172:20:20::5/64  |
+----+---------------------+----------+---------------------------------+--------------+---------------------------------+--------------+---------+-----------------+-----------------------+
```

## Step2-2: 仮想環境でのトラフィック生成

Step2の段階では仮想環境(emulated env)を起動しただけで、まだ実施したいオペレーションのための(オンデマンドな)パラメータ設定やプロセスの起動を行っていません。デモでは外部AS (PNI/POI) 間でトラフィックを生成し、自AS側の経路制御…BGPポリシの変更・修正した際のトラフィック変化確認を行います。そのために以下の準備をします。

### 優先peerの設定

[デモ環境変数](https://www.notion.so/ec6f52c53adc446f827aea81ce610791?pvs=21) 参照

仮想環境用の変数(`demo_vars`)に、優先peer情報を設定します。

- `PREFERED_NODE` : Peer (L3ノード名; AS内部)
- `PREFERED_INTERFACE` : Peer (L3インタフェース名; AS内部)
- `EXTERNAL_ASN` : 対向(外部)AS番号

```bash
# step2.5, preffered peer parameter (use original_asis node/interface name)
PREFERRED_NODE="edge-tk01"
PREFERRED_INTERFACE="ge-0/0/3.0"
EXTERNAL_ASN=65550
```

### 生成するトラフィック情報の設定

clab/flowdata.csv に生成するトラフィックの情報を記入します。

> [!NOTE]
> デモでは実環境で測定したフローデータをもとにプレフィクス感のトラフィック比率を設定しています。

```bash
cat clab/flowdata.csv
```

```
playground/demo/copy_to_emulated_env$ cat clab/flowdata.csv
source,dest,rate
10.0.1.0/24,10.100.0.0/16,2301.98
10.0.1.0/24,10.110.0.0/20,1076.84
10.0.1.0/24,10.120.0.0/17,577.29
10.0.1.0/24,10.130.0.0/21,538.66
10.0.2.0/24,10.100.0.0/16,427.63
10.0.2.0/24,10.110.0.0/20,413.6
10.0.2.0/24,10.120.0.0/17,393.77
10.0.2.0/24,10.130.0.0/21,385.98
10.0.3.0/24,10.100.0.0/16,358.38
10.0.3.0/24,10.110.0.0/20,313.34
10.0.3.0/24,10.120.0.0/17,229.81
10.0.3.0/24,10.130.0.0/21,271.44
10.0.4.0/24,10.100.0.0/16,191.8
10.0.4.0/24,10.110.0.0/20,179.11
10.0.4.0/24,10.120.0.0/17,177.99
10.0.4.0/24,10.130.0.0/21,162.38
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

### 仮想環境の再構成

通常時のPeakトラフィックのFlowDataを所定ファイルパスへコピーする

```
playground/demo/copy_to_emulated_env$ cp clab/before_flowdata.csv clab/flowdata.csv
```

主に endpoint (iperf node) の設定変更とトラフィック生成(iperfの設定と起動)を行います。

```bash
./demo_step2-2.sh
```

実行後少し待つと以下の用のトラフィックが流れていることが確認できます。

![grafana initial traffic](fig/grafana_initial_traffic.png)
