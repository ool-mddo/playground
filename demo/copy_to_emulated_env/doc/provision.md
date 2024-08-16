# copy_to_emulated_env共通環境準備

全体の環境設定については[デモ環境構築](../../../doc/provision.md)を参照してください。

## Gitブランチの選択

ユースケース別に使用する playground (および関連するサブモジュール) のブランチ選択が異なります。
各ユースケースのドキュメントを参照してください。

## Ansible-runner で使用するユーザ設定について

デモで使用する playbook は、検証環境(emulated env; containerlab 等を入れる)サーバの操作を行うために ssh login しています。

- ログインに使用するユーザ名を `demo_vars` の `LOCALSERVER_USER` に定義します。
    - ユーザは ssh login, sudo 実行可能にである必要があります。
- ssh login, sudo パスワードを `env/passwords` ファイルに定義します。
- ssh するサーバのIPアドレスを `inventory/hosts` ファイルに定義します。
    - ここでは、デモシステムとEmulated環境は同一のサーバ上で動作するものとしています。そのためターゲットは localhost になります。この条件であれば変更は不要です。

![system stack](../../../doc/fig/system_stack.drawio.svg)

## Passwordsファイルの作成

ホスト上のユーザ(`LOCALSERVER_USER`)のSSHログインパスワードとsudoパスワードを `passwords` ファイルに記載します

> [!WARNING]
> `passwords`ファイルのファイルパーミッションに注意してください。(`chmod 600`)

```bash
# in playground/demo/copy_to_emulated_env dir
vi env/passwords
```

```yaml
---
"^SSH password:\\s*?$": "login password"
"^BECOME password.*:\\s*?$": "sudo password"
```

## 環境変数ファイルの作成

環境・ユースケースに合わせて環境変数ファイル (`demo_vars`)を編集します。
各ユースケースのドキュメントを参照してください。

```bash
# in playground/demo/copy_to_emulated_env dir
vi demo_vars
```

- runtime and environment: でもで使用するツール関連の設定です。原則変更しません
  - `ANSIBLE_RUNNER_IMAGE` : Ansible runner 用コンテナイメージイメージ名
  - `CRPD_IMAGE` : Emulated env で使用するルータ用コンテナ (Juniper cRPD) のイメージ名
  - `API_PROXY` : デモシステムのREST APIエントリポイント (api-proxy host:port)
  - `API_BRIDGE` : デモシステムに接続するための docker bridge 名
- **demo user & directory: 環境・ユースケースに応じて変更します**
  - `LOCALSERVER_USER` : ホストサーバのSSHログインユーザー名
  - `PLAYGROUND_DIR` : playgroundディレクトリのパス(絶対パス)
- **target network/usecase name: 環境・ユースケースに応じて変更します**
  - `NETWORK_NAME` : 対象にするコンフィグリポジトリのディレクトリ名 (Batfishに入力するネットワーク名)
  - `USECASE_NAME` : ユースケース名
- constants: デモ用のシナリオスクリプト (demo_stepX-X.sh) で使う変数です。原則変更しません。
  - `ANSIBLE_RUNNER_DIR` : Ansible runner実行ディレクトリ
  - `NETWORK_INDEX` : トポロジ可視化ツール(netoviz)に入力するためのネットワーク/スナップショット情報

```bash
# runtime and environment
ANSIBLE_RUNNER_IMAGE="ghcr.io/ool-mddo/mddo-ansible-runner:v3.1.0"
CRPD_IMAGE="crpd:23.4R1.9"
API_PROXY="localhost:15000"
API_BRIDGE="playground_default"

# all steps: demo user & directory
LOCALSERVER_USER=hagiwara
PLAYGROUND_DIR="/home/${LOCALSERVER_USER}/ool-mddo/playground"

# all steps: target network/usecase name
# NETWORK_NAME="nttcom-trial-2022"
NETWORK_NAME="mddo-bgp"
USECASE_NAME="pni_te" # "pni_addlink" or "pni_te" for mddo-bgp network

# constants
NETWORK_INDEX="network_index/${NETWORK_NAME}.json"
ANSIBLE_RUNNER_DIR="${PLAYGROUND_DIR}/demo/copy_to_emulated_env"
ANSIBLE_PLAYBOOK_DIR="${ANSIBLE_RUNNER_DIR}/project/playbooks"
USECASE_CONFIGS_DIR="${ANSIBLE_PLAYBOOK_DIR}/configs"
USECASE_COMMON_NAME=$(echo "$USECASE_NAME" | cut -d_ -f1)
USECASE_COMMON_DIR="${ANSIBLE_PLAYBOOK_DIR}/${USECASE_COMMON_NAME}"
USECASE_DIR="${ANSIBLE_PLAYBOOK_DIR}/${USECASE_NAME}"
```

### トポロジ可視化ツールインデックスファイルの作成

対象にするコンフィグリポジトリ (Batfishに入力するネットワーク) に合わせてトポロジ可視化ツール(netoviz)用のインデックスファイルを用意します。

* ネットワーク、スナップショットについては[デモシステムの構造と設計 - Batfish周辺の設計](../../../doc/system_architecture.md#batfish周辺の設計)を参照してください。
* 可視化ツール(netoviz)インデックスファイルは、複数のスナップショット情報の定義を束ねたリストになっています。スナップショット情報の定義については[デモシステムの構造と設計 - model-info](../../../doc/system_architecture.md#model-info) を参照してください。

デモ用のインデックスファイル: [network_index/mddo-ospf.json](../network_index/mddo-ospf.json)
* デモでは original_asis, emulated_asis, emulated_tobe, original_asis の4つのスナップショットを作成するので、それぞれのスナップショットに対する情報を定義します。
* 4つのスナップショットについては [デモシステムの構造と設計 - 名前空間の変換と変換処理](../../../doc/system_architecture.md#名前空間の変換と変換処理) を参照してください。

```json
[
  {
    "label": "OSPF model (original_asis)",
    "network": "mddo-ospf",
    "snapshot": "original_asis",
    "file": "topology.json"
  },
  ...
]
```
