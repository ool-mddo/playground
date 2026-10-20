# candidate_model_ops: ヘルパースクリプトを scripts/ に移動

## ステータス: 実施済み・動作確認済み (2026-09-30)

移動・パス修正を実施し、`git mv` で履歴を保持した状態でコミット。動作確認として `21_refocus_topology.sh` を `bash -x` で実行し、正常完了を確認済み（詳細は「検証方法」節の末尾に追記）。他のエントリポイント（`00_run_phase.sh` 等、`netoviz_index.py`/`diff2csv.py`/`env_post_clean.sh`/`generate_scrape.sh` の経路を通るもの）は未検証。

## Context

`demo/candidate_model_ops/` 直下にエントリポイント用スクリプト（`00_run_phase.sh` 等の番号付きスクリプト）と、それらから `source`/`bash`/`python3` で呼び出される補助スクリプトが混在しており、見通しが悪くなっている。補助スクリプト群を `demo/candidate_model_ops/scripts/` に移動し、ディレクトリを整理する。

これらのスクリプトは全て「`candidate_model_ops` をカレントディレクトリとして実行される」前提の相対パス（`./demo_vars`、`python3 netoviz_index.py` など）で書かれている。移動対象スクリプト自体は `source` されるか `bash`/`python3 <path>` で子プロセス実行されるだけで、`cd` は一切行われないため、**実行時のカレントディレクトリは常に `candidate_model_ops` のまま**である（スクリプト自身の物理的な置き場所が変わっても、これは変わらない）。したがって：

- 移動しないファイル（`demo_vars`, `network_index/`, 番号付きエントリポイント群）を参照している相対パスは変更不要。
- 移動する側同士の参照（例: `orig_ns_topology.sh` 内の `source ./util.sh`）と、残る側から移動する側への参照（例: `01_candidate_topology.sh` 内の `source ./orig_ns_topology.sh`）は `scripts/` プレフィックスを付ける必要がある。

## 移動対象

`demo/candidate_model_ops/` → `demo/candidate_model_ops/scripts/` (`git mv` で移動し履歴を保持)

指示された7スクリプトに加え、それらから呼び出されている Python スクリプト2点も対象に含める（他の箇所から呼ばれていないことを確認済み）:

- `determine_candidate.sh`
- `env_post_clean.sh`
- `generate_scrape.sh`
- `orig_ns_topology.sh`
- `phase_pre_clean.sh`
- `up_emulated_env.sh`
- `util.sh`
- `netoviz_index.py` (`util.sh` の `generate_netoviz_index()` からのみ呼ばれる)
- `diff2csv.py` (`determine_candidate.sh` の `determine_candidate()` からのみ呼ばれる)

## 修正が必要な箇所

### 移動するスクリプト自身の中の参照（`scripts/` プレフィックス追加）

- `scripts/determine_candidate.sh:4` — `source ./util.sh` → `source ./scripts/util.sh`
- `scripts/determine_candidate.sh:29` — `python3 diff2csv.py ...` → `python3 scripts/diff2csv.py ...`
- `scripts/orig_ns_topology.sh:4` — `source ./util.sh` → `source ./scripts/util.sh`
- `scripts/up_emulated_env.sh:6` — `source ./util.sh` → `source ./scripts/util.sh`
- `scripts/up_emulated_env.sh:89` — `bash env_post_clean.sh ...` → `bash scripts/env_post_clean.sh ...`
- `scripts/util.sh:57` — `python3 netoviz_index.py ...` → `python3 scripts/netoviz_index.py ...`

以下は変更不要（参照先が root に残る `demo_vars` のため）:
- `scripts/env_post_clean.sh:8`, `scripts/generate_scrape.sh:4`, `scripts/phase_pre_clean.sh:4`, `scripts/up_emulated_env.sh:4` の `source ./demo_vars`

`netoviz_index.py` / `diff2csv.py` 自体の中身（引数のパス指定等）はカレントディレクトリに依存しないため修正不要。

### 残るエントリポイントスクリプトからの参照（`scripts/` プレフィックス追加）

- `00_run_phase.sh:62` — `bash phase_pre_clean.sh` → `bash scripts/phase_pre_clean.sh`
- `01_candidate_topology.sh:6` — `source ./orig_ns_topology.sh` → `source ./scripts/orig_ns_topology.sh`
- `01_candidate_topology.sh:73` — `bash generate_scrape.sh` → `bash scripts/generate_scrape.sh`
- `02_benchmark_env.sh:6,8` — `source ./util.sh` / `source ./up_emulated_env.sh` → `./scripts/util.sh` / `./scripts/up_emulated_env.sh`
- `03_candidate_env.sh:6,8,10` — `util.sh` / `up_emulated_env.sh` / `determine_candidate.sh` の3つの `source` → 全て `./scripts/` プレフィックス
- `11_manual_steps.sh:6,8,10` — `orig_ns_topology.sh` / `util.sh` / `up_emulated_env.sh` の3つの `source` → 全て `./scripts/` プレフィックス
- `21_refocus_topology.sh:6` — `source ./orig_ns_topology.sh` → `source ./scripts/orig_ns_topology.sh`

### 対象外（確認済み・変更不要）

- `demo_vars`, `network_index/`, `README.md`, `doc/` 配下: いずれも移動対象ファイルへのパス参照なし（grep で確認済み）。
- プロジェクトルートの `CLAUDE.md` はコマンド例として `./21_refocus_topology.sh` を挙げているのみで、移動対象ファイルを直接参照していないため変更不要。
- playground 全体を検索したが、`candidate_model_ops` 外から移動対象ファイルへの参照は見つからなかった。

## 特に難しい・非推奨の点

なし。全スクリプトが「`candidate_model_ops` で実行される」という同一の前提に一貫して従っており、`source`/`bash`/`python3 <relative-path>` の呼び出しパターンも統一されている。パスプレフィックスの付け替えのみで移動後も問題なく動作する見込み。

## 検証方法

1. `bash -n` で全修正済みシェルスクリプトの構文チェック。
2. `cd demo/candidate_model_ops && source demo_vars && ./00_run_phase.sh -d -u 1` のように `-d`（debug, clabなし）かつ `-u 1`（phase 1 のみ）で軽量実行し、`phase_pre_clean.sh` → `01_candidate_topology.sh`（`orig_ns_topology.sh`, `generate_scrape.sh` 経由）が `scripts/` から正しく読み込まれ、`netoviz_index.py` の呼び出しを含めAPI呼び出しがエラーなく走ることを確認する（実サービスが起動している必要あり）。
3. 可能であれば `21_refocus_topology.sh` も実行し、`orig_ns_topology.sh` 経由の関数群が動作することを確認する。

### 実施結果 (2026-09-30)

- 全スクリプト（移動後の `scripts/*.sh` と、参照を修正した6つのエントリポイントスクリプト）で `bash -n` パス。
- `docker compose up -d` でサービス起動後、`cd demo/candidate_model_ops && source ./demo_vars && bash -x ./21_refocus_topology.sh` を実行し、エラーなく完了を確認。
  - `source ./scripts/orig_ns_topology.sh`（内部で `source ./scripts/util.sh`）が正しく解決され、`generate_original_asis_topology` → `splice_external_as_topology` → `splice_firewall_attributes` → conduit topology 生成 → `convert_namespace` × 3 まで一連の処理が完走。
  - 実行ログに `no such file`, `not found`, `error`, `exception`, `traceback` 等のパターンなし。
  - `docker compose logs`（netomox-exp, model-conductor, bgp-policy-parser, firewall-policy-parser, api-proxy, batfish-wrapper）を確認し、実質的なエラーなし（batfish-wrapper のコンテナ起動直後の接続リトライ警告のみで、本件のスクリプト移動とは無関係）。
  - `api-proxy` のアクセスログに 4xx/5xx なし。
  - 最終的に `GET /topologies/index` で期待通り6スナップショット（`original_asis`, `original_asis_conduit1/2`, `emulated_asis`, `emulated_asis_conduit1/2`）が登録されていることを確認。
- **未検証の経路**: `21_refocus_topology.sh` は独自の `append_netoviz_entries` を使うため、`scripts/util.sh` の `generate_netoviz_index()`（→ `scripts/netoviz_index.py`）や、`scripts/determine_candidate.sh`（→ `scripts/diff2csv.py`）、`scripts/generate_scrape.sh`、`scripts/env_post_clean.sh`、`scripts/up_emulated_env.sh` は通っていない。これらは `00_run_phase.sh` / `01_candidate_topology.sh` / `02_benchmark_env.sh` / `03_candidate_env.sh` の実行時に検証が必要。
