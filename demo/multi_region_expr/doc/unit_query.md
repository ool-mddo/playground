<!-- TOC -->

- [大規模NWの通信シミュレーション性能調査](#%E5%A4%A7%E8%A6%8F%E6%A8%A1nw%E3%81%AE%E9%80%9A%E4%BF%A1%E3%82%B7%E3%83%9F%E3%83%A5%E3%83%AC%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E6%80%A7%E8%83%BD%E8%AA%BF%E6%9F%BB)
  - [動かし方](#%E5%8B%95%E3%81%8B%E3%81%97%E6%96%B9)
    - [単一ブランチのデータ取得](#%E5%8D%98%E4%B8%80%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E3%81%AE%E3%83%87%E3%83%BC%E3%82%BF%E5%8F%96%E5%BE%97)
    - [全ブランチのデータ取得](#%E5%85%A8%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E3%81%AE%E3%83%87%E3%83%BC%E3%82%BF%E5%8F%96%E5%BE%97)

<!-- /TOC -->

---

# 大規模NWの通信シミュレーション性能調査

## 動かし方

### 単一ブランチのデータ取得

特定の pushed_configs branch について・mddo_network = 障害なしの物理スナップショットのみに対して、下記のセクション別にで実行時間を取得します:

- `topology_generate` : トポロジデータの生成 (IP重複チェック等をするためにトポロジデータ生成まで実施)
- `single_snapshot_queries` : Batfish query を投げてCSVデータを生成する (topology_generate に含まれていますがBF周りのオペレーションだけ独立して計測)
- `tracert_neigthbor_region` : 隣接リージョンでサーバ間通信シミュレーション
- `tracert_facing_region` : 対向リージョンでサーバ間通信シミュレーション

コンテナの起動

```bash
# in playground dir
docker compose -f docker-compose.min.yml up
```

データ取得開始

* 引数に対象とする pushed_configs ブランチ名を指定してください
* スクリプトはどのディレクトリから実行しても動作するようになっています

```bash
# in playground/demo/multi_region_expr/unit_query dir
./unit_query_stats.sh 202202demo 2>&1 | tee -a unit_query_stats.log
```

データ抽出

```bash
ruby unit_query_summary.rb < unit_query_stats.log > unit_query_summary.log
```

グラフ作成

```bash
gnuplot -c unit_query_summary.gp .
xdg-open unit_query_summary.png
```

出力

- `unit_query_stats.log` : 実験データ(生ログ)
- `unit_query_summary.log` : 生ログから必要なデータを抽出したもの
- `unit_query_summary.png` : unit_query_summary.log をグラフ化した画像

### 全ブランチのデータ取得

2,5,10,20 region 全てに対して実行する場合、スクリプト側でコンテナの起動・終了を自動でするので、すでに動かしている場合は落としておきます。

```bash
# in playground dir
docker-compose down
```

複数リージョン実行時のサマリデータ + グラフ作成

```bash
# in playground/demo/multi_region_expr/unit_query dir
./unit_query_stats_all.sh
```
