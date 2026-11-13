---
name: release-playground
description: ool-mddo/playground 本体の統合リリース (vX.Y.Z-dev → main → タグ)。全サブモジュールのリリース順序の全体計画づくり、playground の rebase、repos/* と .env のコンテナイメージタグの更新、Release PR 作成、main head SHA を受けてのリリースに使う。「playground を vX.Y.Z リリース」「リリース作業の計画/一覧を出して」のときに使う。個別サブモジュールのリリースは release-submodule を使う。
---

# playground の統合リリース

playground は複数のサブモジュール (repos/*) を束ねる。リリースは **依存順にサブモジュールを先にリリースし、
最後に playground** で、各リポジトリを `release-submodule` の手順で進める。
PR のマージはユーザーが行い、SHA を受け取ってからタグを切る。

## 0. 作業前: 全体計画を出して承認を得る (まだ何も変更しない)

次を調べて一覧にし、ユーザーの承認を得てから着手する:

1. 各リポジトリの dev ブランチ (`vX.Y.Z-dev`) の有無、`origin/main` との関係
   (`git log origin/main..origin/<dev>` / `origin/<dev>..origin/main`)、最新タグ。
2. rebase が必要なリポジトリ。前バージョンの dev ブランチから分岐しているものは main への rebase が必要
   (force push が必要になることをユーザーに説明する)。
3. バージョンの食い違い (チェックリストの番号と VERSION 等)。
4. `Gemfile.lock` など依存の更新要否。
5. playground 作業ツリーの未コミット変更 (リリースに含めるか)。

リリース順 (依存順) の目安:
`netomox (gem)` → `batfish-wrapper` → `netomox-exp` → `model-conductor` → `netoviz` → `playground`
(netomox-exp / model-conductor は netomox の新バージョンを使う。順序は実際の依存で判断する。
mddo-worker 等、今回変更のないサブモジュールは既存タグのまま)。

## 1. サブモジュール群

各リポジトリを `release-submodule` で順に進める。1 リポジトリごとに
「PR 作成 → ユーザーのマージ → SHA を受けてリリース」で止まる。

## 2. playground 本体

### 作業場所: 別 worktree を使う

playground の作業ツリーには未コミットのローカル作業 (デモ設定、compose の一時変更など) があることが多い。
ブランチを切り替えず、スクラッチパッドに worktree を作る:

```bash
git fetch -q origin --tags
W=<scratchpad>/pg-vX.Y.Z
git worktree add -b vX.Y.Z-dev-local "$W" origin/vX.Y.Z-dev
```

### rebase

```bash
cd "$W" && git rebase origin/main
```

- 前バージョンの Release が **squash マージ**のため、前バージョン分のコミットは重複判定されず
  `docs/` 等で衝突することがある。その場合は `git rebase --abort` し、
  **前バージョンに含まれる最後のコミット**を境に `git rebase --onto origin/main <そのコミット>`。
- 残る衝突は通常 `.env` (イメージタグ) とサブモジュール参照のみ。途中コミットでは dev 側の値を採用し、
  最終値は後続の 2 コミットで設定する。

### サブモジュールを main HEAD にする

対象リポジトリごとに worktree 内で submodule を初期化し、**ブランチ `main` をチェックアウトして追従**する
(detached HEAD のまま残さない):

```bash
git submodule update --init --reference <playground>/repos/<name> repos/<name>
cd repos/<name> && git fetch -q origin main --tags && git checkout -q -B main origin/main \
  && git branch -q --set-upstream-to=origin/main main
```

各サブモジュールで **main HEAD = リリースタグが指すコミット** を確認する
(`git rev-parse --short HEAD` と `git rev-parse --short <tag>^{commit}`)。一致しなければ止めて報告。
リリース以外で playground にサブモジュールの参照をコミットするときも、基本は同じ状態 (main の最新 = リリースタグのコミット)
にしてからコミットする。手順は `release-submodule` の「リリース後: playground の `repos/<name>` を main HEAD にする」。

### コミットは 2 つに分ける

1. `Update submodules: <name> vX, ...` — `git add repos/<...>`
2. `Use <name> vX, ... images` — `.env` の `*_IMAGE_TAG` を更新

`.env` で更新するのは **イメージを持つサービス** のタグのみ
(`BATFISH_WRAPPER` / `MODEL_CONDUCTOR` / `NETOMOX_EXP` / `NETOVIZ` 等)。mddo-worker のようにイメージタグが
`.env` にないものは、サブモジュール参照のみ。`BATFISH_IMAGE_TAG` (batfish 本体) は batfish-wrapper と別物なので混同しない。
`-dev` や、ブランチ名のようなタグ (例: `update_readme`) が残っていないか `grep IMAGE_TAG .env` で確認する。
`origin/main` との差分が `.env` と対象 `repos/*` だけであることを `git diff origin/main HEAD --stat` で確認する。

### push と PR

- rebase した場合は force push が必要。ユーザー確認の上、
  `git push --force-with-lease=<dev>:<旧SHA> origin vX.Y.Z-dev-local:vX.Y.Z-dev`。
- PR: `gh pr create --base main --head vX.Y.Z-dev --title "Release vX.Y.Z"`。本文は直近の Release PR
  (`gh pr list --state merged --limit 2`) の形式で、Summary (変更点・サブモジュールのバージョンと SHA・`.env` のタグ) と
  Test plan (`docker compose up -d` で全サービスが起動 / `demo/candidate_model_ops` の `./21_generate_conduit.sh`
  と `./22_up_conduit.sh -s emulated_asis -d` が通る) を載せる。

### リリース (SHA を受け取ってから)

`release-submodule` のフェーズ 2 と同じ (`gh release create vX.Y.Z --target <フル SHA>`、前バージョンの形式のリリースノート)。
その後、worktree とローカルブランチを片付ける:

```bash
git worktree remove --force "$W"; git branch -D vX.Y.Z-dev-local
```

## 完了時の報告

- 全リポジトリのリリース URL と SHA の一覧。
- 未確認事項 (gem 公開・image build/push の Actions 完了など)。
- ユーザーの作業ツリーの dev ブランチが force push 後の履歴と分岐していること (reset は未コミット変更があるため行わない)。
