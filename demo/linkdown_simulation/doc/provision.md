<!-- TOC -->

- [環境準備](#%E7%92%B0%E5%A2%83%E6%BA%96%E5%82%99)
    - [docker host のセットアップ](#docker-host-%E3%81%AE%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97)
        - [docker のインストール ubuntu](#docker-%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB-ubuntu)
        - [docker の設定](#docker-%E3%81%AE%E8%A8%AD%E5%AE%9A)
        - [パッケージ類のインストールubuntu](#%E3%83%91%E3%83%83%E3%82%B1%E3%83%BC%E3%82%B8%E9%A1%9E%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%ABubuntu)
    - [デモ用コード・データの取得とブランチ選択](#%E3%83%87%E3%83%A2%E7%94%A8%E3%82%B3%E3%83%BC%E3%83%89%E3%83%BB%E3%83%87%E3%83%BC%E3%82%BF%E3%81%AE%E5%8F%96%E5%BE%97%E3%81%A8%E3%83%96%E3%83%A9%E3%83%B3%E3%83%81%E9%81%B8%E6%8A%9E)
    - [デモ用ツールのインストール](#%E3%83%87%E3%83%A2%E7%94%A8%E3%83%84%E3%83%BC%E3%83%AB%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)
    - [環境変数の設定](#%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0%E3%81%AE%E8%A8%AD%E5%AE%9A)
    - [コンテナ操作](#%E3%82%B3%E3%83%B3%E3%83%86%E3%83%8A%E6%93%8D%E4%BD%9C)
        - [コンテナイメージのダウンロード](#%E3%82%B3%E3%83%B3%E3%83%86%E3%83%8A%E3%82%A4%E3%83%A1%E3%83%BC%E3%82%B8%E3%81%AE%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89)
        - [コンテナの起動](#%E3%82%B3%E3%83%B3%E3%83%86%E3%83%8A%E3%81%AE%E8%B5%B7%E5%8B%95)
        - [指定コンテナの再起動](#%E6%8C%87%E5%AE%9A%E3%82%B3%E3%83%B3%E3%83%86%E3%83%8A%E3%81%AE%E5%86%8D%E8%B5%B7%E5%8B%95)
        - [コンテナシステムの停止](#%E3%82%B3%E3%83%B3%E3%83%86%E3%83%8A%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%81%AE%E5%81%9C%E6%AD%A2)

<!-- /TOC -->

---

# 環境準備

## docker host のセットアップ

デモ環境には Linux を使用します。(開発は Ubuntu22 で動作確認しています)

デモ用のシステムはスクリプト (ool-mddo/playground リポジトリ) とコンテナイメージで提供されています。

### docker のインストール (ubuntu)

⚠️[2023-03-09] 時点で、Ubuntuの docker.io パッケージでインストールされる docker は version 20.10.12 です。20.10.13 から docker compose コマンドが使えるようになり、今後 docker-compose コマンドではなくこちら (docker サブコマンド) を利用することが推奨されています。ディストリビューションのリポジトリからではなく、Docker のリポジトリから最新版の docker をインストールしてください。

- [Docker Compose V2(Version 2) GA のまとめ - Qiita](https://qiita.com/zembutsu/items/d82b2ae1a511ebd6a350#docker-engine-linux-%E3%81%A7-compose-v2-%E3%82%92%E4%BD%BF%E3%81%86%E3%81%AB%E3%81%AF)
- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
    - [Ubuntu22.04へDockerとDocker Compose v2 をインストール - Qiita](https://qiita.com/kujiraza/items/a8236f65e2c46735ee91)

### docker の設定

Root 権限で docker 操作をするのは手間がかかるので、一般ユーザでも実行できるようにします。

- [Ubuntuでdockerコマンドを非rootユーザーでも使えるようにする方法 – 株式会社シーポイントラボ ｜ 浜松のシステム・RTK-GNSS開発](https://cpoint-lab.co.jp/article/202104/19587/)

### パッケージ類のインストール(ubuntu)

デモ用のスクリプトで ruby をつかっているので、ruby および bundler をインストールしてください

- bsdextrautils : `column` コマンドです

```bash
sudo apt install build-essential
sudo apt install curl jq less csvtool bsdextrautils
```

開発では ruby/3.1 で動作確認しています。一部のスクリプトは ruby 3.1未満では動かないものがあります。ディストリビューションの ruby version が 3.1 未満の場合は [rbenv](https://github.com/rbenv/rbenv) 等でインストールしてください。

- ディストリビューションのruby packageでrubyをインストールする場合

```bash
sudo apt install ruby ruby-dev ruby-bundler
```

- rbenv 等で個別にインストールする場合、rubyビルド用のパッケージが必要になります

```bash
sudo apt install libyaml-dev libssl-dev zlib1g-dev
```

## デモ用コード・データの取得とブランチ選択

デモ用のコードにはデモのためのデータ(コンフィグ類)およびツール類がサブモジュールとして `configs`, `repos` ディレクトリに登録されています。Playground リポジトリ及びそのサブモジュールを clone します。

```bash
git clone https://github.com/ool-mddo/playground.git
cd playground
git submodule update --init --recursive
```

デモでは、ネットワーク = pushed_configs, スナップショット = mddo_network がベースになります。実際のコンフィグ類は `playground/configs/pushed_network/mddo_network` にあります (元のコンフィグリポジトリはこちら: [ool-mddo/pushed_configs](https://github.com/ool-mddo/pushed_configs))。 `queries`, `topologies` ディレクトリも同様に `network/snapshot` 形式のディレクトリ構成でデータを管理しています。

Playground自体のブランチあるいはタグをチェックアウトします。最初はローカルにブランチ持ってきてないのでリモートブランチ (`origin/…`)からローカルブランチを作ります。(この跡実施するサブモジュール等でも同様。)

(⚠️開発中 : `netomox-exp-rest-api`ブランチの最新コミットを使ってください)

```bash
# in playground dir
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
```

デモで使用するコンフィグリポジトリのブランチを用意します。

```bash
# in playground dir
cd configs/pushed_configs
git fetch
git checkout -b 202202demo origin/202202demo
git checkout -b 202202demo1 origin/202202demo
git checkout -b 202202demo2 origin/202202demo
cd ../.. # playground
```

各コンポーネントのブランチあるいはタグを設定します。

(⚠️開発中 : `netomox-exp-rest-api` ブランチの最新コミットを使ってください)

```bash
# in playground dir
cd repos/netomox-exp
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
cd ../batfish-wrapper
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
cd ../netoviz
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
cd ../fish-tracer
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
cd ../model-conductor
git fetch
git checkout -b netomox-exp-rest-api origin/netomox-exp-rest-api
cd ../.. # playground
```

## デモ用ツールのインストール

デモでは [mddo-toolbox](https://github.com/ool-mddo/mddo-toolbox-cli) を使用します。これは、デモシステムの REST API に対する wrapper script です。デモで実施する操作は REST API 経由で行いますが、処理が煩雑になるのと、ある程度簡略化したデータを基に一括で処理できるように、APIの隠蔽とデータ処理(前処理・後処理)を実装してあります。

mddo-toolbox は github packages で管理していますが、インストールの際には認証が必要になります。そのため、事前に Personal Access Token (PAT) が必要です。

- [RubyGemsレジストリの利用 - GitHub Docs](https://docs.github.com/ja/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry)
    - PATには `read:packages` 以上のスコープが必要です
    - bundler で認証を行なう場合、　`bundle config` で設定を登録するか、以下のように環境変数で渡す方法があります。
- [個人用アクセス トークンの作成 - GitHub Docs](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

```bash
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="<USERNAME>:<TOKEN(PAT)>"
```

```bash
# in playground dir
cd demo
bundle install
cd ../ # playground
```

コマンドおよびサブコマンドのオプションは `help` で確認してください。

```bash
# under demo dir
# command help
bundle exec mddo-toolbox help
# sub-command help: help <sub-command>
bundle exec mddo-toolbox help generate_topology
```

## 環境変数の設定

`playground/.env` ファイルにシステムの環境変数を設定します。原則変更は不要ですが、fish-tracer のホスト名の設定のみ各環境に合わせて設定する必要があります。

⚠️ `localhost` や `127.0.0.1` をではなく docker ホスト側のIPやホスト名を設定してください。

例:

```diff
diff --git a/.env b/.env
index 867df0d..481bc56 100644
--- a/.env
+++ b/.env
@@ -30,7 +30,7 @@ TOPOLOGY_BUILDER_LOG_LEVEL=error
 
 # for fish-tracer (entry point = api-proxy)
 # Specify your docker-host IP or HOSTNAME (other than localhost and 127.0.0.1)
-FISH_TRACER_BASE_HOST=Set-IP-or-FQDN
+FISH_TRACER_BASE_HOST=10.0.2.43
 
 # local shared directories
 SHARED_CONFIGS_DIR=./configs
```

## コンテナ操作

デモ用のシステムはコンテナとして提供されます。コンテナの操作には `docker compose` を使用します。このコマンドは`playground` ディレクトリ (docker-compose.yaml があるディレクトリ) で操作してください。

### コンテナイメージのダウンロード

コンテナイメージのダウンロード

```bash
docker compose pull
```

### コンテナの起動

- `-d`オプション(detouch; バックグラウンド実行) をつけずに実行すると、フォアグラウンドで起動します。各コンテナのログがそのまま標準出力に出るので、全体の動きを見ながらやる場合はこちらのほうがわかりやすいかもしれません。

```bash
docker compose up [-d]
```

起動確認

- すべて State: Up になることを確認します。

```bash
docker compose ps
```

```diff
playground$ docker compose ps
NAME                           IMAGE                                                   COMMAND                  SERVICE             CREATED             STATUS              PORTS
playground-api-proxy-1         nginx:1.21                                              "/docker-entrypoint.…"   api-proxy           18 seconds ago      Up 12 seconds       0.0.0.0:15000->80/tcp, :::15000->80/tcp
playground-batfish-1           ghcr.io/ool-mddo/batfish:v0.1.0                         "java -XX:-UseCompre…"   batfish             19 seconds ago      Up 16 seconds       9996-9997/tcp
playground-batfish-wrapper-1   ghcr.io/ool-mddo/batfish-wrapper:netomox-exp-rest-api   "/bin/sh /batfish-wr…"   batfish-wrapper     18 seconds ago      Up 16 seconds       
playground-fish-tracer-1       ghcr.io/ool-mddo/fish-tracer:netomox-exp-rest-api       "yarn dev"               fish-tracer         18 seconds ago      Up 14 seconds       
playground-model-conductor-1   ghcr.io/ool-mddo/model-conductor:netomox-exp-rest-api   "rerun --force-polli…"   model-conductor     18 seconds ago      Up 13 seconds       
playground-netomox-exp-1       ghcr.io/ool-mddo/netomox-exp:netomox-exp-rest-api       "rerun --force-polli…"   netomox-exp         18 seconds ago      Up 14 seconds       
playground-netoviz-1           ghcr.io/ool-mddo/netoviz:netomox-exp-rest-api           "docker-entrypoint.s…"   netoviz             19 seconds ago      Up 16 seconds       0.0.0.0:3000->3000/tcp, :::3000->3000/tcp
```

### 指定コンテナの再起動

一部のコンテナが起動していない場合は再起動を試してみてください。

```
docker compose restart <container>
```

### コンテナ(システム)の停止

```bash
docker compose down
```
