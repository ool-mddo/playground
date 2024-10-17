# 環境準備

全体の環境設定については[デモ環境構築](../../../../doc/provision.md)を参照してください。
copy_to_emulated_env デモ共通の設定については[copy_to_emulated_env共通環境準備](../provision.md)を参照してください。

## Gitブランチの選択

`playground` リポジトリのタグは `v1.8.0` を選択してください

> [!NOTE]
> PNIユースケースはセグメント移転ユースケースのシナリオを拡張する形で構築されています。
> - セグメント移転ユースケースの[環境構築](../move_seg/provision.md)についても参照してください。
> - Step1,2 などの手順は共通です。(PNIユースケースはいまのところ step1-step2 までの実装です。まだ step3-step4 については対応できていません)

PNIユースケースでは、ネットワーク = mddo-bgp, スナップショット = original_asis, emulated_asis がベースになります。

- 実際のコンフィグ類: `playground/configs/mddo-bgp`
- コンフィグリポジトリ: [ool-mddo/mddo-bgp](https://github.com/ool-mddo/mddo-bgp)

## デモ準備

### 入力データ(物理トポロジデータ)

コンフィグファイルから物理(L1)トポロジデータを生成して用意しておく必要がありますが、ここでは割愛します。

- [物理トポロジデータの生成](../../../layer1_topology/doc/operation.md) を参照してください
- 物理トポロジデータは `playground/configs/mddo-bgp/original_asis/batfish/layer1_topology.json` です

### docker compose 環境変数の設定とデモシステムの起動

PNIユースケース (pni_te/addlink) ではトラフィック流量を確認するために grafana/prometheus を追加で使用します。
これらのツールはコンテナで起動しますが、通常使用するデモシステムとは docker compose 設定ファイルを分離しています。(可視化ツール類については [トラフィック可視化](visualize.md)を参照)

- playground
  - docker-compose.yaml : デモシステムとして通常利用するコンテナの定義
  - docker-compose.visualize.yaml : PNIユースケースで使用する可視化ツール関連のコンテナ定義

そのため、docker compose では以下のようにそれぞれの compose ファイルを指定して実行する必要があります。

```bash
docker compose -f docker-compose.yaml -f docker-compose.visualize.yaml up -d
```

ただ、この方法では docker compose コマンド操作をするたびに compose ファイルを指定する必要があり煩雑です。そこで、参照する compose ファイルを環境変数で定義しておきます。

```bash
export COMPOSE_FILE=~/playground/docker-compose.yaml:~/playground/docker-compose.visualize.yaml
docker compose up -d
```

> [!NOTE]
> - 複数の comoopse ファイルを指定する場合、順序があります。最初のファイルを基準にして2つ目以降のファイルを適用していくため、最初のファイルは単独で起動可能な定義になっている必要があります。
> - 相対パスで compose ファイルを指定すると、ファイルが参照可能な特定のディレクトリでしか docker compose を実行できないので、ここでは絶対パス指定にしておきます。

### デモ作業ディレクトリ

デモディレクトリへ移動します。

```bash
cd playground/demo/copy_to_emulated_env/
```

なお、ユースケース固有のデータやスクリプト等は以下のディレクトリに格納されています。

```
+ copy_to_emulated_env         デモディレクトリ
  + project/playbook           デモ用 ansible playbook/script 等のディレクトリ
    + configs                  実行中のデモシナリオの一時データ格納用
    + pni                      pniユースケース共通のもの
      + external_as_topology   pniユースケース用 外部ASトポロジ生成スクリプト
    + pni_adddlink             pni_addlink ユースケース固有のもの
    + pni_te                   pni_te ユースケース固有のもの
```

### トラフィック可視化ツール(Grafana)画面の準備

PNIユースケース (pni_te/addlink) では、仮想環境内でのトラフィック生成や経路制御を行います。トラフィック流量を可視化するためにGrafanaを使用するため、先に準備しておきます。

* grafanaの設定については `playground/assets/grafana/grafana.ini` を参照してください
* データ取得は step2-2 実施後から可能になります。

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

> [!IMPORTANT]
> PNIユースケース (pni_te/addlink) では、ユースケースに応じてどのコンフィグを使用するかを tag で切り替えています。ユースケース別に指定された tag をチェックアウトしてコンフィグを切り替えてください。

```bash
ls playground/configs/mddo-bgp/original_asis/configs/
```
```
$ ls playground/configs/mddo-bgp/original_asis/configs/
Core-TK01  Core-TK02  Edge-TK01  Edge-TK02  Edge-TK03  SW-TK01
```

### (optional) トラフィックの再生成・環境再起動

pni ユースケースでは指定されたフローデータをもとにトラフィックを生成します (step2-2)。トラフィックデータ (flowdata.csv) のデータを差し替えたあと、環境を再起動して emulated env で付加するトラフィックを変えることができます。(実行前にユースケースディレクトリにある flowdata.csv を差し替えてください。)

```bash
# in copy_to_emulated_env dir

# データの差替(例)
# cp project/playbooks/pni_te/before_flowdata.csv project/playbooks/pni_te/flowdata.csv

# 再起動
./demo_step2-2.sh -r
```

### ユースケース別パラメタの設定

ユースケースディレクトリ (`project/playbook/<usecase>/params.yaml`) に各ユースケースで使用するパラメタを設定します。これらのパラメタは主に外部ASトポロジの生成に使用されます。

設定項目の意味は以下のようになります。
* `source_as`, `dest_as`: 自ASに対して、送信元AS・送信先ASの2つのASを設定します。各ASには以下の内容を設定できます。
  * `asn` : AS番号 (必須)
  * `subnet` : 外部AS内部で使用するIPアドレス (必須)
    * /23より大きなアドレスブロックを設定してください。
    * 指定されたアドレスブロックのうち最初の /24 を loopback IP アドレス用・残りのブロックをリンク用に使用します。
  * `allowed_peers` : 外部AS側に設定するエッジルータのIPアドレス (必須)
    * 許可(allowed)リスト形式です。指定されたIPアドレスの BGP peer のみ外部AS側ノードとして作成されます。
    * アドレスは自AS側から見た対向側ルータのIPアドレス (BGP peer のIPアドレス) を指定します。
  * `add_links` : リンク増設を模擬するためのオプション (addlink ユースケース)
    * リンク増設では初期状態ではBGPピアを設定しません。そのままだとBGPコンフィグがないため対向のエッジルータを生成しません。このオプションが設定されている場合、ユースケース中でBGPピアとして設定可能な(L3のみ設定された)対向のエッジルータを作成します。
    * 自AS側でBGPピアとなるルータのルータ名・インタフェース名(L3)・IPアドレスを指定してください。(netmask はルータL3設定をもとに補完されます)
  * `preferred_peer` : 外部AS側の優先経路設定
    * 自AS側のエッジルータ・回線(インタフェース)を指定します。その対向側エッジルータで対象回線を優先するBGPポリシ(優先するlocal preference)が設定されます。

`params.yaml` 設定例

```yaml
---
source_as:
  asn: 65550
  subnet: 169.254.0.0/23
  allowed_peers:
    - 172.16.0.5
    - 172.16.1.9
  add_links:
    - node: edge-tk03
      interface: GigabitEthernet0/0/0/2
      remote_ip: 172.16.1.17
  preferred_peer:
    node: edge-tk01
    interface: ge-0/0/3.0
dest_as:
  asn: 65520
  subnet: 169.254.2.0/23
  allowed_peers:
    - 192.168.0.10
    - 192.168.0.14
    - 192.168.0.18
```

# 補足
## 外部ASトポロジ自動生成の基本動作

PNIユースケースでは以下のルールに基づいて外部ASトポロジを自動生成します。

* 自ASに対して、送信元(source)AS・送信先(destination)ASを作成する
* 各外部ASに対して、外部ASに対する自ASのpeer情報を検索し、1ピアにたいして1つのエッジルータを作成する
  * 外部ASに対して一部のBGPピアのみを再現したいケースのために、BGPピア指定は allowed list 方式をとります
* 外部AS内にはエッジルータを集約するコアルータを置く
* 外部AS内のルータはフルメッシュ接続とする (iBGP設定のため)
  * 現状ルートリフレクタや IGP は設定しません
* コアルータに、AS間トラフィックを生成するための endpoint を接続する
  * endpoint の数やIPアドレスはユースケースごとに設定される flowdata.csv から決められます

こうして生成される外部ASトポロジに対して、ユースケース別のオプションを設定できます。([ユースケース別パラメタの設定](#ユースケース別パラメタの設定) 参照)
