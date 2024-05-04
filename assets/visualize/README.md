# トラフィック可視化

[containerlab](https://containerlab.dev/)で起動したemulated環境で流れているトラフィック量を可視化するためのシステムです。

同梱しているダッシュボードは[JANOG53で発表](https://www.janog.gr.jp/meeting/janog53/as2518/)したユースケースでの使用を想定して作成されています。

# システム構成

仮想ルータ間で流れているトラフィック量は[cAdvisor](https://github.com/google/cadvisor)と[Prometheus](https://prometheus.io/)を使用して収集し、[Grafana](https://grafana.com/)で可視化のダッシュボードを提供しています。

![システム概要図](./overview.drawio.png)

# 使用方法

[デモシステム](../../../doc/provision.md)同様に、使用しているツールは docker compose で管理しています。以下のコマンドを実行してください。

```sh
# playground/demo/copy_to_emulated_env/visualize
docker compose up -d
```

> [!WARNING]
> [デモシステム](../../../doc/provision.md)とは異なる docker 環境として起動します。docker network で使用するIPアドレスが重複しないように注意してください。(参照: [docker-compose.yaml](./docker-compose.yaml) `networks` セクション; `playground/docker-compose.yaml`と明示的に `subnet` を分ける)

デフォルトではGrafanaとPrometheusは以下のポートを使用します。ポート番号を変更したい場合は適宜`docker-compose.yaml`を修正してください。

| ツール | ポート番号 |
| - | - |
| Grafana | 23000 |
| Prometheus | 9090 |

GrafanaとPrometheus起動後、上記のGrafanaのポートにアクセスすることでダッシュボードを閲覧できます。

# ディレクトリ構造

GrafanaとPrometheus用の設定ファイルをそれぞれ`./grafana`と`./prometheus`で管理しています。

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

cAdvisorでトラフィック情報を取得しているため、インターフェース名もコンテナ上から見えるものになっており、実環境のインターフェース名とは異なっています。
これを解決するためにはGrafanaの表示タイミングやPrometheusでの取得タイミングなどで名前空間の変換処理を入れることなどが考えられます。
