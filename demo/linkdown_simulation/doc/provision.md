# 環境準備

共通する環境設定については[デモ環境構築](../../../doc/provision.md)を参照してください。

- `playground` リポジトリの tag は `v1.0.0` を選択してください。
- デモ用システムを起動してください (`docker compose up`)

## デモ用コードの取得

linkdown simulation デモでは、ネットワーク = pushed_configs, スナップショット = mddo_network がベースになります。

- 実際のコンフィグ類: `playground/configs/pushed_network/mddo_network`
- コンフィグリポジトリ: [ool-mddo/pushed_configs](https://github.com/ool-mddo/pushed_configs)

linkdown simulation デモで使用するコンフィグを用意します。コンフィグはブランチ別に管理されているので、各ブランチをローカルにチェックアウトしておきます。

```bash
# in playground dir
cd configs/pushed_configs
git fetch
git checkout -b 202202demo origin/202202demo
git checkout -b 202202demo1 origin/202202demo2
git checkout -b 202202demo2 origin/202202demo3
cd ../.. # playground
```
