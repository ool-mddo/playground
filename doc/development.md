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
