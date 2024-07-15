# 環境準備

全体の環境設定については[デモ環境構築](../../../../doc/provision.md)を参照してください。
copy_to_emulated_env デモ共通の設定については[copy_to_emulated_env共通環境準備](../provision.md)を参照してください。

# Gitブランチの選択

- `playground` リポジトリのタグは `v1.0.0` を選択してください
- デモシステムを起動してください ( `docker compose up` )

セグメント移転ユースケースでは、ネットワーク = mddo-ospf, スナップショット = original_asis, emulated_asis, emulated_tobe がベースになります。

- 実際のコンフィグ類: `playground/configs/mddo-ospf`
- コンフィグリポジトリ: [ool-mddo/mddo-ospf](https://github.com/ool-mddo/mddo-ospf)
