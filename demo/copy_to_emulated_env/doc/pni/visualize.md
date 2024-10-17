# トラフィック可視化

[containerlab](https://containerlab.dev/)で起動したemulated環境で流れているトラフィック量を可視化するためのシステムです。

同梱しているダッシュボードは[PNIユースケース](../../demo/copy_to_emulated_env/README.md)での使用を想定して作成されています。

# システム構成

仮想ルータ間で流れているトラフィック量は[cAdvisor](https://github.com/google/cadvisor)と[Prometheus](https://prometheus.io/)を使用して収集し、[Grafana](https://grafana.com/)で可視化のダッシュボードを提供しています。

![システム概要図](./overview.drawio.svg)

# 使用方法

デモシステムで使用するコンテナ定義 (docker-compose.yaml) に対して追加するツール類のコンテナ定義 (docker-compose.visualize.yaml) を分離しています。環境変数 `COMPOSE_FILE` でこれらの compose ファイルを指定して `docker compose up` してください。(参照: [PNIユースケース/環境準備](../../demo/copy_to_emulated_env/doc/pni/provision.md))

デフォルトではGrafanaとPrometheusは以下のポートを使用します。ポート番号を変更したい場合は適宜`docker-compose.visualize.yaml`を修正してください。

| ツール     | ポート番号 |
| ---------- | ----- |
| Grafana    | 23000 |
| Prometheus |  9090 |
| cAdvisor   | 20080 |

GrafanaとPrometheus起動後、上記のGrafanaのポートにアクセスすることでダッシュボードを閲覧できます。

# ディレクトリ構造

GrafanaとPrometheus用の設定ファイルは `playground/assets/{grafana,prometheus}` にあります。
それぞれ`grafana`と`prometheus`で管理しています。

- `grafana`: Grafanaの設定ファイルを格納したディレクトリ
    - `grafana.ini`: Grafanaのユーザ関連の設定
    - `dashboards`
        - `dashboard.yaml`: ダッシュボードをファイルから読み込むための設定
        - `mddo.json`: 可視化に使用するダッシュボードのデータ(JSON)
    - `datasources`
        - `prometheus.yaml`: データソースとしてPrometheusを登録するための設定
- `prometheus`: Prometheusの設定ファイルを格納したディレクトリ
    - `prometheus.yaml`: cAdvisorカラメトリクスを取得するための設定
　
# 可視化する上でのポイント/改善点

## cAdvisorを使用したメトリクスの取得

emulated環境のルータはコンテナとして起動しているため、インターフェースのカウンタ情報はcAdvisorを使用して取得しています。
これによってemulated環境のコンフィグにSNMP等の監視用のコンフィグの投入をせずともメトリクスの取得が可能になっています。

## ダッシュボード上ではコンテナのインターフェース名が表示されてしまう

cAdvisorでコンテナのトラフィック情報を取得しているため、インターフェース名はコンテナ上から見えるもの (= emulated env の名前) になっており、本来扱いたい本番 (original) 環境のインターフェース名とは異なってしまいます。
これを解決するために [namespace-relabeler](https://github.com/ool-mddo/namespace-relabeler) を cAdvisor の前段に置きます。namespace-relabeler は prometheus からのメトリクス要求を cAdvisor にプロキシしますが、その際 cAdvisor から取得したデータの中にあるインタフェース名を original env の名前に変換します。

> [!NOTE]
> 変換テーブルを取り扱うために、対象のネットワーク名が必要になります。これはデモシナリオ(ユースケース)に応じて設定されるものなので、シナリオ実行時に外から与える必要があります。
