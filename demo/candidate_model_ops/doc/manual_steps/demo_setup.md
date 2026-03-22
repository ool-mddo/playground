# デモ環境セットアップ

デモ環境セットアップについては既存のドキュメントを参考にしてください。
* [デモ環境セットアップ(ワーカー分離版)](/doc/provision_workers.md)

## デモ設定

- playground version: `v2.5.2`
- ユースケース名: `manual_steps`
- ユースケースパラメタ: `usecases/manual_steps/mddo-bgp/params.yaml`
  - [candidate_model_ops (運用者の試行錯誤をモデル操作で実現する)](https://github.com/ool-mddo/playground/blob/main/demo/candidate_model_ops/README.md) を拡張しているのでそちらを参照。(`l3_preallocated_resources` セクションを拡張)
- 使用するネットワーク: [mddo-bgp](https://github.com/ool-mddo/mddo-bgp)

## 事前定義リソースのためのユースケースパラメタ

`l3_preallocated_resources` セクションを以下のように拡張しています。

事前定義(preallocated)リソース: オペレーション上、仮想NW起動後にad-hocにリソースを追加できないため事前に定義します。

> [!WARNING] 注意
> - いま、Layer3以上のトポロジのみ仮想NWとして再現する形になっているため、L3レイヤに対する prealloc resource を定義すること
> - 定義するのは基本的にノード。prealloc resource として設定されたノード(およびそのインタフェース)は、全てshutdown bridgeと呼ぶ専用のOVS Bridge(Seg_empty00)に接続される形で起動する。(起動直後の接続は内部的に事前定義される: [設計・実装](tech_design.md)参照)

事前定義(preallocated)リソース種類
- type `node`
    - L3ノード(ルータ)
    - 起動後に実施する手動オペレーションの中で登場するルータを定義しておく。
    - 既存のルータ名が指定されている場合、既存ルータに対して空のインタフェース(`interfaces` で定義)を追加する。
    - `emulated_params` が指定される場合、このセクションから下のデータはそのまま仮想NWコントローラ(Containerlab)に渡される。
- type `segment`
    - L3セグメント(セグメントノード)
    - 手動オペレーションの中でルータを他のノードに切り替えるときに必要なセグメント(ブリッジ)を定義しておく

```yaml
l3_preallocated_resources:
  - type: node
    name: as65520-edge01
    asn: 65520
    interfaces:
      - Ethernet3
  - type: node
    name: edge-tk12
    interfaces:
      - 1/1/c12/1
      - 1/1/c21/1
    emulated_params:
      license: ./sros_license.txt
      image: localhost/nokia/srsim:25.7.R1
      kind: nokia_srsim
      type: SR-2s
      components:
        - slot: A
        - slot: B
        - slot: 1
          type: xcm-2s
          sfm: sfm-2s
          env:
            NOKIA_SROS_CARD: xcm-2s
            NOKIA_SROS_MDA_1: s36-100gb-qsfp28
          mda:
            - slot: 1
              type: s36-100gb-qsfp28
  - type: segment
    name: Seg_192.168.1.0/24
    comment: will-be connect edge-tk12 to core-tk01
  - type: segment
    name: Seg_empty01
    comment: will-be connect as65520-edge01 to edge-tk12
```

# 環境起動

環境のセットアップ、システム起動については [デモ環境セットアップ(ワーカー分離版)](/doc/provision_workers.md)を参照してください。手順に沿って、コントローラー、及びワーカーを起動します。
