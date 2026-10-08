# デモ環境セットアップ(ワーカー分離版)

## 概要

playground `v2.0.0` 以降, candidate_model_ops では複数の "worker" を利用して異なるノードで emulated env を起動させます。

> [!NOTE]
> worker分離は将来的な並列同時検証を想定したアーキテクチャ検証のための機能です。現時点では構造として並列実行可能なシステム構造を整理するために実装されています。`v2.1.0` ではデモシナリオ実行制御(コントローラ側)では並列実行させていません。

> [!NOTE]
> * `v2.0.0` の段階では playground リポジトリにコントローラ・ワーカーそれぞれの機能が同梱されています(分離されていません)。
> * `v2.1.0` 以降、以下の形でリポジトリを分離しています
>   * playground/repos/mddo-worker: worker リポジトリ ([mddo-worker](https://github.com/ool-mddo/mddo-worker))
>   * worker用ansible-edaコンテナ ([ansible-eda](https://github.com/ool-mddo/mddo-ansible-eda))
> * `v2.1.0` 以降、ワーカーでのcontainerlab実行はホストOS上のネイティブ実行ではなく、docker上で実行する形に変更しました。
>   * containerlabコンテナ ([clab-docker](https://github.com/ool-mddo/mddo-clab-docker))

システムとしては以下のような形になります。

![system architecture](fig/worker_architecture.png)
![system stack](fig/worker_system_stack.drawio.svg)

* デモシナリオの実行制御(control)は demo/candidate_model_ops にある shell script です。
* 自動実行処理(ansible)は ansible-eda (Event Driven Ansible) を使用し、REST APIベースで行われます。
  * コントローラ・ワーカーそれぞれで ansible-eda を起動します。(役割に応じて異なるAPIを持ちます: 各rulebook参照)
  * ansibleによるコントローラからワーカーノードのリモート操作はしていません。ワーカーのAPIをキックして、ワーカーノード上でローカルにplaybookを実行します
  * ansible-eda コンテナイメージは共通です。

| role | image | repository | rulebook | playbook |
|------|-------|------------|----------|----------|
| controller | mddo-ansible-eda/v0.1.0 | playground | assets/ansible-eda | demo/candidate_model_ops/playbooks |
| worker | mddo-ansible-eda/v0.1.0 | mddo-worker | ansible-eda | playbooks |

# デモシステムのセットアップと起動

共通部分については [デモ環境セットアップ(共通)](./provision.md)を参照してください。

> [!WARNING]
> docker engine, OVSについては以下のバージョンで動作確認をしています。古いバージョンでは動作しないかもしれません。
> * Ubuntu: 22.04
> * Docker: 27.3.1
> * Open vSwitch: 2.17.9 (ovs-vsctl, ovsdb-server)

## コントローラー

playground `v2.1.0` に切り替えます。

```shell
cd playground
git checkout v2.1.0
```

サブモジュールを更新します。

```shell
git submodule update --init --recursive
```

demo_varsファイルを編集します。

```shell
cd demo/candidate_model_ops
vi demo_vars
```

```shell
# コントローラのIPアドレス(単一)
CONTROLLER_ADDRESS="192.168.23.33"
# ワーカーのIPアドレス(複数カンマ区切り)
WORKER_ADDRESS="192.168.23.33,192.168.23.34"
```

上記の例では、192.168.23.33 のノードはコントローラとしてもワーカーとしても使用しています。


デモシステムのコンテナを起動します。

```shell
docker compose -f docker-compose.yaml -f docker-compose.visualize.yaml  up -d
```

## ワーカー

playgroundリポジトリをクローンし `v2.1.0` に切り替えます。

> [!NOTE]
> playbroundとworkerの動作確認バージョンをセットにして管理しているためplaygroundリポジトリを起点にしていますが、使用するのはworkerだけです

```shell
git clone https://github.com/ool-mddo/playground.git
cd playground
git checkout v2.1.0
```

サブモジュール(repos/mddo-worker)を更新します。

```shell
git submodule update --init --recursive
```

コンテナルータ(cRPD)のライセンスを用意します。

```shell
cd playground/repos/mddo-worker
vi clab/license.key
```

ワーカー側コンテナを起動します。

> [!IMPORTANT]
> * `.env` にcontainerlab用の作業ディレクトリパス指定があります (環境変数 `WORKERDIR`)。このディレクトリは絶対パスで指定してください。相対パスだとうまく動作しません。
> * mddo-workerはplayground同様に user `mddo` のホームディレクトリ下にplaygroundディレクトリを設置している想定で構成されています。

```shell
# playground/repos/mddo-worker dir
docker compose up -d
```
