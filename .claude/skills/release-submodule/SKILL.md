---
name: release-submodule
description: ool-mddo のサブモジュールリポジトリ (netomox, batfish-wrapper, netomox-exp, model-conductor, netoviz, mddo-worker など) 1 つを vX.Y.Z-dev ブランチからリリースする。「<repo> を vX.Y.Z としてリリース」「<repo> の Release PR を作って」「main head <SHA> をリリース」のときに使う。playground 本体のリリースは release-playground を使う。
---

# サブモジュールのリリース (dev ブランチ → main → タグ)

対象リポジトリは `repos/<name>/` (netomox のみ `~/ool-mddo/netomox`)。
フローは **PR 作成 → (ユーザーが) マージ → main head の SHA を受け取って tag/release** の 2 フェーズ。
マージはユーザーが行う。マージ前に勝手にタグやリリースを作らない。

## フェーズ 1: PR 作成

### 1. 状態を調べる (変更しない)

```bash
cd <repo> && git fetch -q origin --tags
git status -sb
git tag --sort=-v:refname | head -3
git log --oneline origin/main..origin/<dev>      # dev にあって main にないコミット
git log --oneline origin/<dev>..origin/main      # main にあって dev にないコミット
```

- `<dev>` は `vX.Y.Z-dev`。バージョンの出所 (`VERSION` 定数、`package.json` 等) とユーザー指定のバージョンが
  食い違っていないか確認し、食い違いは先に報告する
  (例: チェックリストが v0.14.0 でも dev の VERSION が 0.14.1 なら、リリース名は v0.14.1 か確認)。
- 直近のマージ済み PR (`gh pr list --state merged --limit 2`) でタイトル・本文の形式を確認する。

### 2. main との関係で分岐する

| `origin/<dev>..origin/main` | 対応 |
|---|---|
| 空 (main の先頭から分岐) | rebase 不要。そのまま PR |
| 1 コミット (前バージョンの Release squash) | 下の「rebase」へ |

dev ブランチが「前バージョンの dev ブランチ」から分岐している場合、main 側は前バージョンの
**squash マージ**になっている。

### 3. rebase (必要な場合のみ)

```bash
git rebase origin/main
```

- 前バージョンの個別コミットは patch-id で重複と判定され、自動で落ちることが多い
  (`dropping ... patch contents already upstream`)。
- 重複判定が効かず衝突する場合 (複数コミットが 1 つに squash されている等) は、`git rebase --abort` して
  **前バージョンに含まれる最後のコミットを境にする**:
  `git rebase --onto origin/main <前バージョン最後のコミット>`
- rebase 後は dev ブランチの履歴が書き換わる。push 前にユーザー確認を取り、
  `git push --force-with-lease origin <dev>` を使う (単純な `--force` は使わない)。

### 4. Ruby 系リポジトリ (netomox-exp, model-conductor): 依存更新とテスト

```bash
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM=corestate55:$(cat /home/hagiwara/.ssh/ool-mddo-token)
export BUNDLE_WITH=test          # rspec は optional group
bundle update netomox            # 必要なときのみ。出力にトークンを出さない (sed でマスク)
bundle exec rubocop
bundle exec rspec
```

- `Gemfile.lock` は `.gitignore` 対象 (追跡外) なのでコミットは発生しない。`git status` で確認する。
- トークンの値を表示・記録しない。

Node 系 (netoviz): `npm run lint` と `npm test`。Python 系 (batfish-wrapper) はテストなし (CI 任せ)。
テストが落ちる場合は PR を作らず報告する。

### 5. PR 作成

```bash
gh pr create --base main --head <dev> --title "Release vX.Y.Z" --body "..."
```

本文は直近のマージ済み PR の形式に合わせる:
`## Summary` (vX.Y.Z リリース + 変更点の箇条書き) / `## Test plan` (実行した検証は `[x]`、CI 確認は `[ ]`) /
末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)`。
PR URL と変更内容を報告し、「CI を確認してマージ → main head の SHA を連絡」を依頼して止まる。

## フェーズ 2: リリース (ユーザーから main head の SHA を受け取ってから)

```bash
cd <repo> && git fetch -q origin --tags
git rev-parse origin/main          # ユーザー指定の SHA と一致するか確認 (不一致なら止めて報告)
git log --oneline -2 origin/main   # "Release vX.Y.Z (#N)" であることを確認
gh release view <前バージョン> --json body -q .body   # リリースノートの形式を参照
gh release create vX.Y.Z --target <フル SHA 40桁> --title vX.Y.Z --notes "..."
```

- `--target` は **フル SHA**。短縮 SHA は 422 で拒否される。
- リリースノートは前バージョンの形式に合わせる
  (`## What's Changed` / `* Release vX.Y.Z by @corestate55 in <PR URL>` + 変更点 / `**Full Changelog**: .../compare/<前>...<今>`)。
- tag の push は `gh release create` が行う。image の build & push は GitHub Actions 側。
  完了は確認していないことを報告に含める。
- netomox は `lib/netomox/version.rb` の変更 push で gem が GitHub Packages に公開される
  (`.github/workflows/packages.yaml`)。

### リリース後: playground の `repos/<name>` を main HEAD (= リリースタグのコミット) にする

リリースを作ったら、**playground の作業ツリーの `repos/<name>` を、`main` ブランチの最新 (リリースしたコミット) にそろえる**。
playground でサブモジュールの参照をコミットする (`Update submodules: ...`) のは、**基本的に、この状態にしてから**。
dev ブランチや detached HEAD のまま、参照をコミットしない。

```bash
cd <playground>/repos/<name>
git status --short                                   # 未コミットの変更が無いこと (あれば止めて報告)
git checkout -q main && git pull -q --ff-only origin main --tags
git rev-parse HEAD                                   # = リリースタグが指すコミットか確認
git rev-list -n1 vX.Y.Z                              #   (一致しなければ止めて報告)
git status -sb                                       # ## main...origin/main (差が無いこと)
```

- 作業中の dev ブランチ (未 push のコミットを含む) から切り替える前に、`git status` と `git log origin/<dev>..<dev>` で、
  未コミット・未 push が無いことを確認する (あれば先に push するか、ユーザーに確認する)。
- 一致を確認できたら、playground で `git add repos/<name>` する。`.env` のイメージタグは、image の build 完了を
  確認してから更新する (別コミット。`release-playground` の「コミットは 2 つに分ける」と同じ)。

## 報告

作業ごとに、対象 (PR/リリース URL)・コミット SHA・実行した検証の結果・未確認事項 (Actions の完了など) を簡潔に報告する。
