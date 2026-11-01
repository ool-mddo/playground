# 調査・実施記録: ランタイムのセキュリティ更新 (2026-11)

**ステータス: 実施済み**(ローカル環境とコンテナイメージの更新を完了。未確認事項は末尾)
方針・更新手順の現行記述: [docs/design_notes/development.md](../../design_notes/development.md#ランタイムベースイメージのバージョン管理)

## きっかけ

直近 1 か月で python / ruby / nodejs に脆弱性対応のリリースがあった(例: Node.js 10/21 の security release、
Ruby 3.4.10 以降)。ローカル (anyenv) とコンテナイメージの両方を更新した。

## ローカル環境 (anyenv)

| ランタイム | 更新前 (global) | 更新後 (global) | 削除 |
|---|---|---|---|
| node | 24.21.0 | 24.22.2 | 16.16.0, 18.18.0 |
| ruby | 3.4.10 | 3.4.12 | 3.0.2, 3.1.2 |
| python | 3.11.5 | 3.12.16 | 3.8.13, 3.10.5 |

- build プラグイン (node-build / ruby-build / python-build) が古く、最新版を知らなかったため先に `git pull` した。
- 残した旧バージョン: node 22.23.2 / 24.21.0、ruby 3.4.10、python 3.11.5 / 3.12.5、go 1.19.1(go は未使用)。

## コンテナイメージ

Dockerfile のベースイメージをパッチ番号まで固定した(ビルド済みイメージを見なくても使用バージョンを特定できる)。

| サブモジュール | 更新前 | 更新後 | リリース |
|---|---|---|---|
| model-conductor | `ruby:3.4.10-slim` | `ruby:3.4.12-slim` | v1.19.0-dev(未リリース) |
| netomox-exp | `ruby:3.4.10-slim` | `ruby:3.4.12-slim` | v1.21.0-dev(未リリース) |
| firewall-policy-parser | `python:3.12-slim` | `python:3.12.16-slim` | v0.2.0-dev(未リリース) |
| batfish-wrapper | `python:3.11-slim` | `python:3.12.16-slim` | v1.2.1 |
| bgp-policy-parser | `python:3.11-slim` | `python:3.12.16-slim` | v0.8.1 |
| state-conductor | `python:3.12-slim` | `python:3.12.16-slim` | v1.0.2 |
| netoviz | `node:24-alpine` | `node:24.22.2-alpine` | v0.10.1 |
| fish-tracer | `node:16.13-bullseye-slim` | 対象外 | - |

## Python 3.11 → 3.12 移行の検証

- bgp-policy-parser: 3.12.16 でビルドし `test/test.py` 6 tests passed(3.11.18 でも同結果)。
  `pytest.ini` の都合で `pytest test/test.py` と明示する必要がある。
- batfish-wrapper: 3.12.16 でビルド、`compileall` 成功、`app` の import は batfish への接続試行まで進んだ
  (pybatfish 2026.09.17 / pandas 3.1.0 / Flask 3.1.3 に解決)。
- 全体: CI で作ったイメージで `docker compose up -d` し、`21_generate_conduit.sh`(mddo-fw / refocus_topology)が
  終了コード 0 で完走。6 snapshot(original_asis / emulated_asis と conduit1/2 の各ペア)が API で取得でき、
  各コンテナのログにエラーなし。

## 未確認・残課題

- bgp-policy-parser を呼ぶシナリオ(`demo/bgp-test/` など)での結合動作。デモ `21_*` は呼ばない。
- `22_up_conduit.sh`(ContainerLab を使うエミュレーション環境の起動)。
- netomox gem の CI は Ruby 3.0 のまま(`gemspec` は `>= 3.0.2`)。Ruby 3.0 は EOL のため、別途判断が必要。
- netoviz の `package.json` の `version`(0.2.0)と state-conductor の `pyproject.toml` の `version`(0.1.0)が
  タグと食い違っている(以前から)。
- netoviz の `CLAUDE.md` / `docs/architecture.md` のベースイメージ記述 (`node:24-alpine`) は、
  次回の dev ブランチで `node:24.22.2-alpine` に直す。
- netomox-exp / model-conductor / firewall-policy-parser はリリース前。playground の `.env` は
  これらを `-dev` タグのまま使っている。
