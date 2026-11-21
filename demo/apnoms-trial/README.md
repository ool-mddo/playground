# APNOMS 向けデモ (apnoms-trial)

APNOMS 向けの実験・データ取り (mddo-mregnw ネットワークでのリージョン数別の評価) に使った
デモ環境と実行スクリプト一式の保存場所。

> **現行 (v2.12.x) のデモとは互換性がない。** 旧 `apnoms-trial` ブランチ (v2.1.1 ベース) の最終版を、
> 実行可能な状態でこのディレクトリに保存したもの。`demo/copy_to_emulated_env/` と内容が重複するが、
> 意図的に独立させている (step2 系のスクリプト・playbook など、実験用に書き換えた箇所がある)。
> 現行の playground の起動方法 (`docker-compose.yaml` / `.env`) では動かない。下記の手順で起動すること。

## 構成

| パス | 内容 |
|---|---|
| `apnoms.env` | 実験時の `.env` (v2.1.1 当時のコンテナイメージタグ)。`SHARED_*_DIR` のみ、このディレクトリから実行する前提で `../../` 付きに変更 |
| `docker-compose.min.yaml` | 実験用の最小構成 compose (netoviz 旧版 / bgp-policy-parser / batfish / netomox-exp / model-conductor / api-proxy)。`repos/*` の bind mount は削除済み |
| `assets/api-proxy/min.conf`, `assets/batfish/log4j2.yaml` | 上記 compose が使う設定 (main では削除・変更済みのため複製) |
| `demo_vars` | 全体の設定。`NETWORK_NAME=mddo-mregnw` / `USECASE_NAME=pni_addlink` / runner イメージ `v3.1.0-apnoms` |
| `demo_step1-1.sh` `demo_step1-2.sh` `demo_step2-1.sh` `demo_step2-2.sh` `demo_wait.sh` `demo_task.sh` `demo_remove.sh` | 実験の各ステップ |
| `run_all_demos.sh` | リージョン別ブランチを切り替えながら全ステップを実行し、リソース使用量・所要時間のログを `run_logs/` に取る |
| `run_logs/` | ログ集計・グラフ化 (`*.gp`, `plot_region_data.py`, `topo_specs.sh`)。ログ本体は `.gitignore` 済み |
| `multi_region/` | グラフ定義 (`region_data_{single,double}.gp`)。`demo/multi_region_expr/multi_region/` に追加していたもの |
| `network_index/` | netoviz index。`mddo-mregnw.json` が実験用 |
| `project/`, `env/`, `inventory/`, `ansible.cfg` | ansible-runner 用のプロジェクト (step2-1/2-2 の playbook、テンプレート) |

## 再現に必要な環境

| 要素 | 内容 |
|---|---|
| コンテナイメージ | `apnoms.env` のタグ (batfish v0.3.0 / batfish-wrapper v1.1.1 / bgp-policy-parser v0.7.0 / model-conductor v1.12.0 / netomox-exp v1.13.0 / netoviz v0.7.0 など) |
| ansible runner | `ghcr.io/ool-mddo/mddo-ansible-runner:v3.1.0-apnoms` (`profile_tasks` 有効。mddo-ansible-runner の同名タグ) |
| ネットワーク設定 | `configs/mddo-mregnw` (サブモジュール。下記のリージョン別ブランチ) |
| エミュレーション | containerlab + cRPD (`demo_vars` の `CRPD_IMAGE`)、OVS |
| 実行ホスト | `PLAYGROUND_DIR=/home/${LOCALSERVER_USER}/playground` (`demo_vars`、`run_all_demos.sh` はホームディレクトリ直下の `playground` を前提) |

### mddo-mregnw のリージョン別ブランチ

`configs/mddo-mregnw` はリージョン数ごとにブランチが分かれている。

| ブランチ | リージョン数 | `demo_task.sh` の traceroute 先 |
|---|---|---|
| `main` / `2region` | 2 | 2.2.2.2 |
| `5region` | 5 | 3.3.3.4 |
| `10region` | 10 | 5.5.5.6 |
| `20region` | 20 | 10.10.10.11 |
| `40region` | 40 | 20.20.20.21 |

playground は submodule を `2region` 先頭 (`1cf4bc3`) に固定している。
`run_all_demos.sh` は `BRANCHES` の各ブランチを `git checkout` して実行する。
`BRANCHES` は最終版では `("2region")` のみで、他は行頭コメントを外して有効にする。

> 実行後は submodule の作業ツリーが別ブランチに移り、playground 側の `git status` に差分が出る。
> `git -C configs/mddo-mregnw checkout 2region` で元に戻すこと。

## 実行手順

前提: 現行の playground のサービス (`docker compose up`) を停止しておく
(project 名・ポート 15000 が衝突する。`docker-compose.min.yaml` は project 名を `playground` に固定している)。

```bash
cd demo/apnoms-trial

# 1. サービス起動 (v2.1.1 当時のイメージタグ)
docker compose --env-file apnoms.env -f docker-compose.min.yaml up -d

# 2. 単一リージョンを手動で実行する場合 (configs/mddo-mregnw は対象ブランチを checkout 済みとする)
./demo_step1-1.sh        # トポロジ生成 (original_asis) + netoviz index
./demo_step1-2.sh        # BGP ネットワークの場合: 外部 AS トポロジを展開してマージ
./demo_step2-1.sh        # namespace 変換 + emulated 環境の設定生成 / containerlab デプロイ (-d: デプロイなし)
./demo_step2-2.sh        # iperf クライアント/サーバ設定 (-r: containerlab 再起動, -d: デプロイなし)
./demo_wait.sh           # 120 秒待機
./demo_task.sh 2region   # traceroute
sudo ./demo_remove.sh    # 環境の撤去

# 3. リージョン別ブランチの全ステップ + ログ採取を一括実行
./run_all_demos.sh       # ログ: run_logs/<yyyymmddhhmm>/<branch>/

# 4. グラフ化 (run_logs/ 内。<date_dir> は run_all_demos.sh が作った yyyymmddhhmm ディレクトリ)
cd run_logs
./topo_specs.sh <date_dir>                 # トポロジ規模 (links/nodes) の CSV を標準出力へ
python3 plot_region_data.py -d <date_dir>  # リージョン別の集計 (region_data_list.csv など)
gnuplot -c region_data_single.gp <date_dir>   # 同 double / cpu_usage.gp / mem_usage.gp も同じ引数
```

- ansible-runner (step2-1/2-2) は containerlab サーバへの SSH/sudo パスワードを要求する。
  `env/passwords` の書式は各 `demo_step2-*.sh` 冒頭のコメントを参照。
- `multi_region/region_data_{single,double}.gp` は `multi_region_summary.dat` (`demo/multi_region_expr/multi_region/` の
  集計スクリプトの出力) を入力にする別系統のグラフ定義。使い方は `demo/multi_region_expr/` を参照。
- `plot_region_data.py` が生成するファイルと `topo_specs.sh` の出力の使い分けは、各スクリプトの冒頭を参照。

## 現行デモとの主な違い

- `docker-compose.min.yaml` の bind mount (`./repos/*`) を削除。main の `repos/*` は新しく、固定タグのイメージと一致しないため。
  イメージだけで動作する。
- compose はこのディレクトリから実行し、共有データ (`configs/` `queries/` `topologies/` `ttp/` `usecases/`) は
  playground ルートの同名ディレクトリを使う (`apnoms.env` の `SHARED_*_DIR`)。
  → 現行デモと同じデータディレクトリを使うため、実験前後で `queries/` `topologies/` の内容が変わる。
- step2 系の playbook / スクリプトが、mddo-mregnw (リージョン別構成) 向けに書き換えられている。
- 実行ログの採取 (`run_all_demos.sh`)・集計・グラフ化は、このデモ固有。

## 由来

- 元ブランチ: `ool-mddo/playground` の `apnoms-trial` (v2.1.1 `5d5b230` から分岐、最終コミット `e449c42`)。
  ブランチは履歴ごと廃止し、最終版のみをこのディレクトリに保存した。
- 計画: [docs/work/plans/apnoms_trial_preservation.md](../../docs/work/plans/apnoms_trial_preservation.md)
