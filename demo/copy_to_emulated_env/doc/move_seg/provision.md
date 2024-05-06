# 環境準備

環境設定については[デモ環境構築](../../../../doc/provision.md)を参照してください。

- `playground` リポジトリのタグは `v1.0.0` を選択してください
- デモシステムを起動してください ( `docker compose up` )

セグメント移転ユースケースでは、ネットワーク = mddo-ospf, スナップショット = original_asis, emulated_asis, emulated_tobe がベースになります。

- 実際のコンフィグ類: `playground/configs/mddo-ospf`
- コンフィグリポジトリ: [ool-mddo/mddo-ospf](https://github.com/ool-mddo/mddo-ospf)

## 検証環境(Emulated env)ホスト側の環境設定

### Ansible-runner で使用するユーザ設定について

デモで使用する playbook は、検証環境(emulated env; containerlab 等を入れる)サーバの操作を行うために ssh login しています。

- ログインに使用するユーザ名を `demo_vars` の `LOCALSERVER_USER` に定義します。
    - ユーザは ssh login, sudo 実行可能にである必要があります。
- ssh login, sudo パスワードを `env/passwords` ファイルに定義します。
- ssh するサーバのIPアドレスを `inventory/hosts` ファイルに定義します。
    - ここでは、デモシステムとEmulated環境は同一のサーバ上で動作するものとしています。そのためターゲットは localhost になります。この条件であれば変更は不要です。

![system stack](../../../../doc/fig/system_stack.drawio.svg)

### 環境変数ファイルの作成

環境に合わせて環境変数ファイル (`demo_vars`)を編集します。デモスクリプト実行環境に合わせて以下の変数を変更してください。

```bash
# in playground/demo/copy_to_emulated_env dir
vi demo_vars
```

- `ANSIBLE_RUNNER_IMAGE` : Ansible runner 用コンテナイメージイメージ名
- `CRPD_IMAGE` : Emulated env で使用するルータ用コンテナ (Juniper cRPD) のイメージ名
- `API_PROXY` : デモシステムのREST APIエントリポイント (api-proxy host:port)
- `API_BRIDGE` : デモシステムに接続するための docker bridge 名
- `LOCALSERVER_USER` : ホストサーバのSSHログインユーザー名
- `PLAYGROUND_DIR` : playgroundディレクトリのパス(絶対パス)
- `ANSIBLE_RUNNER_DIR` : Ansible runner実行ディレクトリ
- `NETWORK_NAME` : 対象にするコンフィグリポジトリのディレクトリ名 (Batfishに入力するネットワーク名)
- `NETWORK_INDEX` : トポロジ可視化ツール(netoviz)に入力するためのネットワーク/スナップショットの情報

```bash
ANSIBLE_RUNNER_IMAGE="ghcr.io/ool-mddo/mddo-ansible-runner:v3.1.0"
CRPD_IMAGE="crpd:23.4R1.9"
API_PROXY="localhost:15000"
API_BRIDGE="playground_default"
LOCALSERVER_USER=mddo
PLAYGROUND_DIR="/home/${LOCALSERVER_USER}/playground"
ANSIBLE_RUNNER_DIR="${PLAYGROUND_DIR}/demo/copy_to_emulated_env"
NETWORK_NAME="mddo-ospf"
NETWORK_INDEX="network_index/${NETWORK_NAME}.json"
```

### Passwordsファイルの作成

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

### トポロジ可視化ツールインデックスファイルの作成

対象にするコンフィグリポジトリ (Batfishに入力するネットワーク) に合わせてトポロジ可視化ツール(netoviz)用のインデックスファイルを用意します。

* ネットワーク、スナップショットについては[デモシステムの構造と設計 - Batfish周辺の設計](../../../../doc/system_architecture.md#batfish周辺の設計)を参照してください。
* 可視化ツール(netoviz)インデックスファイルは、複数のスナップショット情報の定義を束ねたリストになっています。スナップショット情報の定義については[デモシステムの構造と設計 - model-info](../../../../doc/system_architecture.md#model-info) を参照してください。

デモ用のインデックスファイル: [network_index/mddo-ospf.json](../../network_index/mddo-ospf.json)
* デモでは original_asis, emulated_asis, emulated_tobe, original_asis の4つのスナップショットを作成するので、それぞれのスナップショットに対する情報を定義します。
* 4つのスナップショットについては [デモシステムの構造と設計 - 名前空間の変換と変換処理](../../../../doc/system_architecture.md#名前空間の変換と変換処理) を参照してください。

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
