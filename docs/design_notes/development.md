# 開発用・開発者向け

## 開発用サブモジュールの更新チェック

デモシステム開発のために、repos 下にソースコードを配置してコンテナにマウントしています。
これらは git submodule として管理されています。開発中はこの中でコードの修正・ブランチの切り替え等を実施しながら作業します。その際、コンテナイメージは更新しているのに repos 下のサブモジュールを更新していない・ブランチを切り替え忘れていて変更が反映されていない、などのミスがあります。

これらを防止するために repos 下のリポジトリ情報と `.env` で設定されているコンテナイメージのタグ情報を一覧表示するスクリプトがあります。

インストール (ubuntu)
* スクリプト内で CSV データの表示のために `column` コマンド (bsdextrautils package) を使用しています。

```bash
sudo apt install bsdextrautils
```

チェック

```bash
# playground dir
./check_repos.sh
```

実行すると以下のように情報が表示されます。

* current-branch: repos 下サブモジュールで現在チェックアウトされているブランチ名
* current-tag: 現在チェックアウトされているコミットにタグが設定されていればそのタグを表示
* target-branch/tag: `.env` で定義されている各サブモジュールに対応するコンテナイメージのタグ情報
* up-to-date?: 現在のブランチ (current-branch) が最新かどうか。最新ではない = リモートブランチに pull していない更新がある状態です。その場合、この列は `NO!` になります。(その場合は `git pull` して最新にしてください。)

```text
playground$ ./check_repos.sh 
repository                  current-branch     current-tag   target-branch/tag   up-to-date?
repos/batfish-wrapper       main               v1.1.1        v1.1.1              yes
repos/bgp-policy-parser     main                             v0.5.0              yes
repos/fish-tracer           main               v1.0.0        v1.0.0              yes
repos/model-conductor       main               v1.8.0        v1.8.0              yes
repos/namespace-relabeler   fix-ns-table-api                 fix-ns-table-api    yes
repos/netomox-exp           main               v1.10.0       v1.10.0             yes
repos/netoviz               main               v0.7.0        v0.7.0              yes
```

* 通常、current-branch または current-tag は target-branch/tag と一致します。
* 上記の実行例では、bgp-policy-parser は branch/tag どちらも一致していません。これは、main branch HEAD が v0.5.0 tag をつけられたコミットよりも先に進んでいるためです。

## netomox (gem) の修正を伴う開発

[netomox](https://github.com/ool-mddo/netomox) はトポロジデータを扱う Ruby gem で、netomox-exp と model-conductor のコンテナイメージに
`bundle install` (GitHub Packages) でインストールされています (`/usr/local/bundle/gems/netomox-<version>/`)。
`repos/netomox-exp/lib` などは bind mount されますが、**gem の中身は mount されない**ため、netomox を修正してもコンテナには反映されません。
netomox の修正を伴う作業では、`docker-compose.override.yaml` でローカルの netomox のソースを gem のディレクトリに bind mount して開発します。
(netomox への属性追加 (例: fhrp) のように、netomox → netomox-exp / model-conductor → netoviz の順に変更が連なる作業を想定。)

### 前提

* netomox を playground と同じ階層に clone しておく (`playground` の隣の `netomox` ディレクトリ。以下は `../netomox` で説明します)。
* netomox の作業ブランチ (例: `v0.14.0-dev`) をチェックアウトしておく。

### 手順

**1. コンテナ内の netomox の gem ディレクトリ名を確認する**

```bash
# playground dir
docker compose exec -T netomox-exp ls /usr/local/bundle/gems | grep netomox
docker compose exec -T model-conductor ls /usr/local/bundle/gems | grep netomox
# 例) netomox-0.13.0
```

この名前 (バージョン付き) が次の mount 先になります。`.env` のイメージタグを変えると gem のバージョンも変わるので、その都度確認します。

**2. `docker-compose.override.yaml` を作る**

playground ディレクトリ直下に作ります (**コミットしない**。`.gitignore` に入っています)。
`netomox-0.13.0` の部分は手順 1 で確認した名前にします。

```yaml
# Local development override (DO NOT COMMIT)
# Use netomox source (local working copy) instead of the netomox gem installed in the images.
# NOTE: the path contains the gem version (netomox-0.13.0); update it when the image changes.
services:
  netomox-exp:
    volumes:
      - type: bind
        source: ../netomox/lib/netomox
        target: /usr/local/bundle/gems/netomox-0.13.0/lib/netomox
        read_only: true
  model-conductor:
    volumes:
      - type: bind
        source: ../netomox/lib/netomox
        target: /usr/local/bundle/gems/netomox-0.13.0/lib/netomox
        read_only: true
```

**3. override を指定して起動する**

```bash
# playground dir
docker compose -f docker-compose.yaml -f docker-compose.override.yaml up -d
# 以降の docker compose コマンドにも同じ -f を付ける (または環境変数で指定する)
export COMPOSE_FILE=docker-compose.yaml:docker-compose.override.yaml
```

* `-f` を指定すると、`docker-compose.override.yaml` は**自動では読み込まれません**。`docker-compose.visualize.yaml` を併用する場合は 3 つとも指定します。
* `down` / `restart` / `exec` なども同じ `-f` で実行します。片方だけ指定すると override が外れ、イメージ内の元の gem に戻ります。
* すでに起動している環境に適用するときは `docker compose ... up -d` で netomox-exp / model-conductor のコンテナが作り直されます (データのボリュームは消えません)。

**4. 組み込まれたことを確認する**

```bash
docker compose exec -T netomox-exp bundle exec ruby -e 'require "netomox"; puts Netomox::VERSION; puts defined?(Netomox::Topology::MddoFhrp).inspect'
docker compose exec -T model-conductor bundle exec ruby -e 'require "netomox"; puts Netomox::VERSION'
```

`Netomox::VERSION` は mount したローカルの `lib/netomox/version.rb` の値になります。追加したクラスなどが見えることを確認します。

**5. netomox を修正したら**

* コンテナを再起動する (netomox-exp / model-conductor の `rerun` は gem のディレクトリを監視しないため、再起動しないと反映されません)。

```bash
docker compose restart netomox-exp model-conductor
```

* `repos/netomox-exp/lib` や `repos/model-conductor/lib` の修正は、これまでどおり bind mount で即時反映されます (`rerun` が検知)。
* netoviz は gem に依存しない (JSON を読むだけ) ため、netomox の変更に netoviz 側の対応は不要です。

### ホストでの rspec 実行 (netomox の公開前)

netomox-exp / model-conductor の spec を、ローカルの netomox で実行できます。`RUBYLIB` に指定したディレクトリが gem より先に
`$LOAD_PATH` に入るため、Gemfile / Gemfile.lock を変更せずに、インストール済みの古い netomox の代わりにローカルの netomox が使われます。

```bash
# netomox-exp (rspec/rack-test は optional group `test`)
cd repos/netomox-exp
RUBYLIB=/home/<user>/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rspec
RUBYLIB=/home/<user>/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rake rubocop

# model-conductor
cd repos/model-conductor
RUBYLIB=/home/<user>/ool-mddo/netomox/lib bundle exec rspec
RUBYLIB=/home/<user>/ool-mddo/netomox/lib bundle exec rake rubocop
```

* 組み込まれているか確認するには `bundle exec ruby -e 'require "netomox"; puts $LOADED_FEATURES.grep(/netomox\/version/)'` でパスを見ます
  (`RUBYLIB` に指定した `lib/netomox/version.rb` が表示されれば OK)。
* **この方法が使えるのは、Gemfile の netomox の制約 (`>= x.y.z`) を、ホストにインストール済みの gem が満たしているときだけです。**
  netomox の新バージョンを公開して Gemfile の制約を引き上げた後は、ホストに新しい gem が無いと
  `Could not find gem 'netomox (>= 0.14.0)' in locally installed gems` で bundler が失敗します。
  その場合は GitHub Packages の認証情報を設定して公開版をインストールします (この場合 `RUBYLIB` は不要)。

```bash
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="USERNAME:GITHUB_PAT"   # read:packages 権限のトークン
bundle install
```

  開発中は Gemfile の制約を引き上げず (netomox の公開後にまとめて引き上げる)、`RUBYLIB` で確認するのが手軽です。

### netomox のリリースから本番イメージでの確認まで

netomox の修正が完了したら、公開版に切り替えます。

1. **netomox を公開する**: `lib/netomox/version.rb` を更新してコミットし、ブランチを push する。
   `lib/netomox/version.rb` を含む push で CI (`.github/workflows/packages.yaml`) が起動して gem を GitHub Packages に公開します
   (`gh run list --branch <branch>` で `Run test and lint` と `build and push rubygem package` の成功を確認する)。
   CI は Ruby 3.0 で rspec / rubocop を実行します。3.1 以降の構文 (引数省略の `f(x:)` など) を使わないでください。
2. **netomox-exp / model-conductor の Gemfile を更新する**: `gem 'netomox', '>= <新バージョン>'` にしてコミット・push する。
   CI が新しい netomox で rubocop + rspec を実行し、成功するとイメージ (`ghcr.io/ool-mddo/<service>:<ブランチ名>`) を build / push します。
   **公開前にこの変更を push すると、CI が netomox の新機能を取得できず失敗します。** 必ず netomox の公開後に行ってください。
3. **playground の `.env` のイメージタグを更新する**: 新しいイメージ (ブランチ名のタグ) を指定する。
4. **override を外して公開イメージで確認する**:

```bash
docker compose -f docker-compose.yaml -f docker-compose.override.yaml down
mv docker-compose.override.yaml /tmp/   # override を外す (削除でもよい)
docker compose pull netomox-exp model-conductor
docker compose up -d
docker compose exec -T netomox-exp ls /usr/local/bundle/gems | grep netomox     # 新しいバージョンの gem
cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh
```

### 注意点

* **mount 先の gem のバージョンが合っていないと効きません。** イメージ内の gem が `netomox-0.14.0` なのに mount 先が `netomox-0.13.0` のままだと、
  mount 先は存在しないディレクトリになり、gem には何も反映されません (エラーも出ません)。手順 4 の確認コマンドで、追加したクラスなどが見えることを必ず確認します。
* **依存 gem の追加・更新には対応できません。** mount するのは `lib/netomox` だけです。netomox の gemspec に依存を追加した場合は、
  コンテナに gem を入れるか、公開してイメージを作り直す必要があります。
* **override は開発用の一時的なものです。** コミットしないでください (`.gitignore` 済み。`git add -A` でも入りません)。
  動作確認の最後には必ず override を外し、公開イメージで確認してください。
* ローカルの netomox を使った確認結果は、公開版 (イメージ) でも同じになることを確認してから完了とします。

## YAMLフォーマットチェック

[YAMLlint](https://github.com/adrienverge/yamllint) を使ってください。playground ディレクトリに設定ファイル `.yamllint` があります。

インストール (ubuntu)

```bash
sudo apt install yamllint
```

チェック

```bash
# playground dir
yamllint docker-compose*.yaml
find demo/copy_to_emulated_env/project/playbooks/ -name "*.yaml" | xargs yamllint
```

## shell script 文法チェック

[ShellCheck](https://www.shellcheck.net/) を使ってください。(設定ファイルはありません。)

インストール (ubuntu)

```bash
sudo apt install shellcheck
```

チェック

```bash
# playground/demo/copy_to_emulated_env dir
shellcheck *.sh
```
