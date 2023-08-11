# 大規模NWのリンクダウンパターン性能調査

## 単一ブランチのデータ取得

特定の pushed_configs branch に対しするデータを取得します。

コンテナの起動

```bash
# in playground dir
docker compose -f docker-compose.min.yaml up
```

データ取得開始

* 引数に対象とする pushed_configs ブランチ名を指定してください
* スクリプトはどのディレクトリから実行しても動作するようになっています

```bash
# in playground/demo/multi_region_expr/multi_region dir
./multi_region_stats.sh 202202demo2
```

実行すると、 `docker_stats_<branch>_<epoch>` ディレクトリが作成され、その中にデータが配置されます。
  - `exec.log` : テスト実行ログ(ターミナルに出力される情報)...セクションごとのタイムスタンプ、 `time` コマンドの実行結果
  - `stats.log` : `docker stats` のログ...おおもとの実験結果データ
  - `*.dat` : stats.log にあるデータを種類別に集計したデータファイル
  - `graph.png` : dat をグラフ化した画像
  - 他リージョンブランチに対しての実行はデータ生成に時間がかかるので、再作成しなくてもデータ使えるように出力結果だけバックアップしてあります
    - `models.tar.gz` : models ディレクトリ (CSV) のバックアップ
    - `topologies.tar.gz` : topologies ディレクトリ (トポロジjson) のバックアップ

```
$ ls ./docker_stats_202202demo2_xxxx/
block_in.dat   cpu_percent.dat  graph.png        mem_usage.dat  net_in.dat   stats.log
block_out.dat  exec.log         mem_percent.dat  models.tar.gz  net_out.dat  topologies.tar.gz
```

## 全ブランチのデータ取得

2,5,10,20 region 全てに対して実行する場合、スクリプト側でコンテナの起動・終了を自動でするので、すでに動かしている場合は落としておきます。

```bash
# in playground dir
docker compose down
```

データ生成開始

* スクリプトはどのディレクトリから実行しても動作するようになっています

```bash
# in playground/demo/multi_region_expr/multi_region dir
./multi_region_stats_all.sh
```

## 補足: 複数branch実行結果の比較

グラフ生成は multi_region_stats_all.sh に組み込まれています。取得済みのデータについて手動でグラフを生成し直す場合(グラフの設定変更等)は以下のように実施します。

複数リージョン実行時のサマリデータ + グラフ作成

```bash
# データディレクトリ確認:
#   multi_region_stats_all.sh で作っていれば
#   2,5,10,20 region, 4パターンが作成時間順に並ぶはずなので、最後に作った4ディレクトリを確認する
#   手動でデータ作っている場合は対象を並べて引数に渡すこと
# ls -1tr | grep docker_stats_ | tail -n4

# in playground/demo/multi_region_expr/multi_region dir
ls -1tr | grep docker_stats_ | tail -n4 | xargs ruby multi_region_summary.rb > multi_region_summary.dat
# グラフ生成
gnuplot -c multi_region_summary.gp .
# ubuntu desktop の場合: 画像を開く
xdg-open multi_region_summary.png
```

## 補足: データの確認方法

### グラフ表示して可視化

- L1, L3 で各リージョンが環状につながったグラフになるかどうか
  - 20リージョン構成は視認で確認するのは難しい

### リージョン間通信ができているかどうか

- 環境が大きくなると視認で確認するのが難しい: リージョン間通信ができるかどうか・traceroute hops が狙った hop になっているかどうか
  - [単位クエリ](./unit_query.md)のデータとして取得

### 生成されたトポロジデータに対するL1 description check

```bash
# demo/multi_region_expr/multi_region

# リンク数の確認 (双方向に出るので本数は x2 で出る)
bundle exec mddo-toolbox check_l1_descr -n pushed_configs -s mddo_network | jq '. | length'
# Description check が 'Correct' 出ないものを確認
# -> 基本的にサーバ側には description 情報がないのでサーバインタフェースだけが出る
bundle exec mddo-toolbox check_l1_descr -n pushed_configs -s mddo_network | jq '.[] | select(.message != "Correct")'
```
