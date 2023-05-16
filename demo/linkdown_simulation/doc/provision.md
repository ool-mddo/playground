<!-- TOC -->

- [環境準備](#%E7%92%B0%E5%A2%83%E6%BA%96%E5%82%99)
    - [デモ用コードの取得](#%E3%83%87%E3%83%A2%E7%94%A8%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E5%8F%96%E5%BE%97)

<!-- /TOC -->

---

# 環境準備

共通する環境設定については[デモ環境構築](../../../doc/provision.md)を参照してください。

- `playground` リポジトリのブランチは `netomox-exp-rest-api` を選択してください。
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
