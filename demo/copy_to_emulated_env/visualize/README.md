# トラフィック可視化
[containerlab](https://containerlab.dev/)で起動したemulated環境で流れているトラフィック量を可視化するためのシステムです。

同梱しているダッシュボードは[JANOG53で発表](https://www.janog.gr.jp/meeting/janog53/as2518/)したユースケースでの使用を想定して作成されています。

# システム構成
仮想ルータ間で流れているトラフィック量は[cAdvisor](https://github.com/google/cadvisor)と[Prometheus](https://prometheus.io/)を使用して収集し、[Grafana](https://grafana.com/)で可視化のダッシュボードを提供しています。

![システム概要図](./overview.drawio.png)

# 使用方法
使用しているツールはdocker composeで管理しています。起動するにはdockerおよびdocker composeが使用できる状態で以下のコマンドを実行してください。
```sh
$ sudo docker compose up -d
```

デフォルトではGrafanaとPrometheusは以下のポートを使用します。ポート番号を変更したい場合は適宜`docker-compose.yaml`を修正してください。

| ツール | ポート番号 |
| - | - |
| Grafana | 23000 |
| Prometheus | 9090 |

GrafanaとPrometheusのコンテナが起動したら上記のGrafanaのポートにブラウザでアクセスすることで、トラフィック量可視化のダッシュボードを閲覧できます。

# ディレクトリ構造
GrafanaとPrometheus用の設定ファイルをそれぞれ`./grafana`と`./prometheus`で管理しています。

- `grafana`: Grafanaの設定ファイルを格納したディレクトリ
    - `dashboards`
        - `dashboard.yaml`: ダッシュボードをファイルから読み込むための設定
        - `mddo.json`: 可視化に使用するダッシュボードのデータ(JSON)
    - `datasources`
        - `prometheus.yaml`: データソースとしてPrometheusを登録するための設定
- `prometheus`: Prometheusの設定ファイルを格納したディレクトリ
    - `prometheus.yaml`: cAdvisorカラメトリクスを取得するための設定
　
# 今後の改善点
## ダッシュボード上ではコンテナのインターフェース名が表示されてしまう
ダッシュボード上ではコンテナのインターフェース名がそのまま見えているため、実機のインターフェース名との差異が存在します。
これを解決するためにはGrafanaまたはPrometheusで名前空間を変換する仕組みが必要になります。
