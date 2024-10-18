# デモ環境セットアップ

## 概要

環境セットアップは大きく以下の2段階あります。

- 各デモ (linkdown simulation, copy to emulated env) に共通するデモ用システムのセットアップ
    - デモシステムについては [デモシステムの構造と設計](system_architecture.md) を参照してください
- [実環境を検証環境にコピーするデモ ("環境コピー"デモ, copy to emulated env)](../demo/copy_to_emulated_env/README.md) で使用する、検証環境(emulated env)のためのセットアップ

![system stack](fig/system_stack.drawio.svg)

> [!NOTE]
> - デモ環境には Linux を使用します。(開発側では Ubuntu22 で動作確認しています)
> - デモシステムはスクリプト ([ool-mddo/playground リポジトリ](https://github.com/ool-mddo/playground)) とコンテナイメージで提供されています。
> - [環境コピー](../demo/copy_to_emulated_env/README.md) デモで使用する grafana/prometheus についてはデモシステムとは定義(compose file)を分けてあります。詳細は[トラフィック可視化](../demo/copy_to_emulated_env/doc/pni/visualize.md), [PNIユースケース/環境準備](../demo/copy_to_emulated_env/doc/pni/provision.md) ドキュメントを参照してください。

# デモシステムのセットアップ(デモ共通)

## GithubアカウントとPATの準備

デモシステムのコンテナイメージ・Rubyパッケージの管理には [Github packages](https://github.com/orgs/ool-mddo/packages) を使用しています。このパッケージリポジトリからソフトウェアをダウンロードする際に認証が必要になるため、以下のページを参考にPAT (Personal Access Token)を用意してください。

- [個人用アクセス トークンの作成 - GitHub Docs](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- PAT には `read:packages` 以上のスコープを設定する必要があります

## Docker のインストール (ubuntu)

> [!WARNING]
> [2023-03-09] 時点で、Ubuntuの docker.io パッケージでインストールされる docker は version 20.10.12 です。20.10.13 から docker compose (compose サブコマンド)が使えるようになり、今後 docker-compose ではなくこちらを利用することが推奨されています。ディストリビューションのリポジトリからではなく、Docker のリポジトリから最新版の docker をインストールしてください。

- [Docker Compose V2(Version 2) GA のまとめ - Qiita](https://qiita.com/zembutsu/items/d82b2ae1a511ebd6a350#docker-engine-linux-%E3%81%A7-compose-v2-%E3%82%92%E4%BD%BF%E3%81%86%E3%81%AB%E3%81%AF)
- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
    - [Ubuntu22.04へDockerとDocker Compose v2 をインストール - Qiita](https://qiita.com/kujiraza/items/a8236f65e2c46735ee91)

## Docker の設定

Root 権限で docker 操作をするのは手間がかかるので、一般ユーザでも実行できるようにします。

- [Ubuntuでdockerコマンドを非rootユーザーでも使えるようにする方法 – 株式会社シーポイントラボ ｜ 浜松のシステム・RTK-GNSS開発](https://cpoint-lab.co.jp/article/202104/19587/)

## ツールのインストール(ubuntu)

デモ操作・デモ用スクリプト内で使用しているツールをインストールします。

- bsdextrautils : `column` コマンドです

```shell
sudo apt install build-essential
sudo apt install curl jq less csvtool bsdextrautils
```

## Rubyのインストール

デモ用ツールがrubyで作成されているため、ruby および bundler をインストールしてください。

開発では ruby/3.1 で動作確認しています。一部のスクリプトは ruby 3.1未満では動かないものがあります。ディストリビューションの ruby version が 3.1 未満の場合は [rbenv](https://github.com/rbenv/rbenv) 等でインストールしてください。

- ディストリビューションのruby packageでrubyをインストールする場合

```shell
sudo apt install ruby ruby-dev ruby-bundler
```

- rbenv 等で個別にインストールする場合、rubyビルド用のパッケージが必要になります

```shell
sudo apt install libyaml-dev libssl-dev zlib1g-dev
```

## デモ用コードの取得

デモ用のコードにはデモのためのデータ(コンフィグ類)およびツール類がサブモジュールとして `configs`, `repos` ディレクトリに登録されています。Playground リポジトリ及びそのサブモジュールを clone します。

```shell
git clone https://github.com/ool-mddo/playground.git
cd playground
git submodule update --init --recursive
```

Playground自体のブランチあるいはタグをチェックアウトします。初期状態ではローカルにブランチを持ってきてないので、リモートブランチ (`origin/…`)からローカルブランチを作ります。(このあと実施するサブモジュール等でも同様。)

```shell
# in playground dir
git fetch
git checkout refs/tags/v1.0.0
```

各コンポーネントのブランチあるいはタグを設定します。

```shell
# in playground dir
cd repos/netomox-exp
git fetch
git checkout refs/tags/v1.0.0
cd ../batfish-wrapper
git fetch
git checkout refs/tags/v1.0.0
cd ../netoviz
git fetch
git checkout refs/tags/v0.3.0
cd ../fish-tracer
git fetch
git checkout refs/tags/v1.0.0
cd ../model-conductor
git fetch
git checkout refs/tags/v1.0.0
cd ../.. # playground
```

> [!NOTE]
> * `repos` ディレクトリ内の各コンポーネントのソースコードを用意しておくのは開発用途です。ここに配置したコードをデモシステムの各コンテナにマウントして、コードの修正・デバッグ・動作確認できるようになっています。
> * ソースコードの修正を行わない場合はコンテナへのマウントを解除して使用することも可能です。(`playground/docker-compose.yaml` を修正してください。その場合  `repos` 下のリポジトリのブランチ設定は不要で、デモシステムで動かすソフトウェアバージョンはコンテナイメージのタグだけで決定できます。コンテナイメージのタグ設定は `.env` を参照してください。)

## デモ用ツールのインストール

デモでは [mddo-toolbox](https://github.com/ool-mddo/mddo-toolbox-cli) を使用します。これは、デモシステムの REST API に対する wrapper script です。デモで実施する操作は REST API 経由で行いますが、RESTだと処理が煩雑になるため、ある程度簡略化したデータを基に一括で処理できるように、APIの隠蔽とデータ処理(前処理・後処理)を実装してあります。

mddo-toolbox パッケージ(rubygem)化して github packages で管理しています。そのためインストールの際には認証が必要になります。あらかじめ Personal Access Token (PAT) を用意しておいてください。

- [RubyGemsレジストリの利用 - GitHub Docs](https://docs.github.com/ja/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry)
    - PATには `read:packages` 以上のスコープが必要です
    - bundler で認証を行なう場合、`bundle config` で設定を登録するか、以下のように環境変数で渡す方法があります。

```shell
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="<USERNAME>:<TOKEN(PAT)>"
```

```shell
# in playground dir
cd demo
bundle install
cd ../ # playground
```

コマンドおよびサブコマンドのオプションは `help` で確認してください。

```shell
# under demo dir

# command help
bundle exec mddo-toolbox help
# sub-command help: help <sub-command>
bundle exec mddo-toolbox help generate_topology
```

## 環境変数の設定

`playground/.env` ファイルにシステムの環境変数を設定します。原則変更は不要ですが、fish-tracer のホスト名の設定のみ各環境に合わせて設定する必要があります。

> [!WARNING]
> `localhost` や `127.0.0.1` をではなく docker ホスト側のIPやホスト名を設定してください。

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

デモ用のシステムはコンテナとして提供されます。コンテナの操作には `docker compose` を使用します。

### コンテナイメージのダウンロード

コンテナイメージのダウンロード

```shell
docker compose pull
```

### コンテナの起動

- `-d`オプション(detouch; バックグラウンド実行) をつけずに実行すると、フォアグラウンドで起動します。各コンテナのログがそのまま標準出力に出るので、全体の動きを見ながらやる場合はこちらのほうがわかりやすいかもしれません。

```shell
docker compose up [-d]
```

起動確認

- すべて State: Up になることを確認します。

```shell
docker compose ps
```

```
playground$ docker compose ps
NAME                           IMAGE                                     COMMAND                  SERVICE             CREATED              STATUS              PORTS
playground-api-proxy-1         nginx:1.21                                "/docker-entrypoint.…"   api-proxy           About a minute ago   Up 47 seconds       0.0.0.0:15000->80/tcp, :::15000->80/tcp
playground-batfish-1           ghcr.io/ool-mddo/batfish:v0.1.0-update1   "java -XX:-UseCompre…"   batfish             About a minute ago   Up About a minute   9996-9997/tcp
playground-batfish-wrapper-1   ghcr.io/ool-mddo/batfish-wrapper:v1.0.0   "/bin/sh /batfish-wr…"   batfish-wrapper     About a minute ago   Up About a minute   
playground-fish-tracer-1       ghcr.io/ool-mddo/fish-tracer:v1.0.0       "yarn dev"               fish-tracer         About a minute ago   Up 55 seconds       
playground-model-conductor-1   ghcr.io/ool-mddo/model-conductor:v1.0.0   "rerun --force-polli…"   model-conductor     About a minute ago   Up 51 seconds       
playground-netomox-exp-1       ghcr.io/ool-mddo/netomox-exp:v1.0.0       "rerun --force-polli…"   netomox-exp         About a minute ago   Up 55 seconds       
playground-netoviz-1           ghcr.io/ool-mddo/netoviz:v0.3.0           "docker-entrypoint.s…"   netoviz             About a minute ago   Up About a minute   0.0.0.0:3000->3000/tcp, :::3000->3000/tcp
```

### 指定コンテナの再起動

一部のコンテナが起動していない場合は再起動を試してみてください。

```
docker compose restart <container>
```

### コンテナ(システム)の停止

```shell
docker compose down
```

# 検証環境(emulated env)のセットアップ

[環境コピー](../demo/copy_to_emulated_env/README.md) デモでは、本番同等の構成をコンテナを使って再現した検証環境 (Emulated env) を構築します。その際、検証環境の操作には ansible を使用します。コンテナとコンテナ間接続は containerlab で管理します。

## Pythonのインストール

Ansibleを使用するために python + pip (python3系) をインストールします。

```shell
sudo apt install python3 python3-pip
```

## Ansible-runnerのインストール

ansible-runner をインストールします。

- [ansible-builderとansible-runnerを試してみた - うさラボ](https://usage-automate.hatenablog.com/entry/2021/07/15/191500)

```shell
sudo python3 -m pip install ansible-runner
```

デモで使用する ansible runner のコンテナイメージは[リポジトリ](https://github.com/ool-mddo/mddo-ansible-runner)に用意してあります。
デモで使用するコンテナイメージは `demo/copy_to_emulated_env/demo_vars` の環境変数で指定します。(設定済み…詳細は[環境準備ドキュメント](../demo/copy_to_emulated_env/doc/move_seg/provision.md)参照)

ansible runner 実行時(デモ用スクリプトの中で呼ばれています)に指定されたコンテナイメージがなければ自動でダウンロード (pull) が実行されますが、ここではあらかじめ pull しておきます。

```shell
docker pull ghcr.io/ool-mddo/mddo-ansible-runner:v3.1.0
```

## Containerlabのインストール

検証環境(emulated env)を構築するためにContainerlabをインストールします。

- [Installation - containerlab](https://containerlab.dev/install/)

```shell
sudo bash -c "$(curl -sL https://get.containerlab.dev)"
```

## Open vSwitch (OVS) のインストール

Containerlab で構成する検証環境(emulated env)のL2として docker ホスト側のOVS bridgeを使用するため、OVSをインストールします。

```shell
sudo apt install -y openvswitch-switch
```

## 検証環境内で使用するCNFの設定

### Juniper cRPDのインポート

cRPDコンテナイメージは適宜入手してください。

- [コンテナ化RPDとは |cRPD |ジュニパーネットワークス](https://www.juniper.net/documentation/jp/ja/software/crpd/crpd-deployment/topics/concept/understanding-crpd.html)
- [Docker |へのcRPDのインストールcRPD |ジュニパーネットワークス](https://www.juniper.net/documentation/jp/ja/software/crpd/crpd-deployment/topics/task/crpd-linux-server-install.html)

以下のコマンドでローカルの docker にインポートします。

```shell
docker load -i junos-routing-crpd-amd64-docker-XX.XR.XX.tgz
```
```
$ docker image ls | grep crpd
crpd                                   23.4R1.9             9ed2949df81f   4 months ago    502MB
```

インポートしたコンテナの情報を `demo/copy_to_emulated_env/demo_vars` の環境変数で指定します。(設定済み…詳細は[環境準備ドキュメント](../demo/copy_to_emulated_env/doc/move_seg/provision.md)参照)

MDDO PJにて動作確認できているバージョンは `junos-routing-crpd-amd64-docker-23.4R1.9.tgz` です。

### Juniper cRPDのライセンス適用

cRPDコンテナ起動後にライセンスを適用する必要があります。詳細については [環境コピーデモ step②](../demo/copy_to_emulated_env/doc/move_seg/step1-2.md)を参照してください。
