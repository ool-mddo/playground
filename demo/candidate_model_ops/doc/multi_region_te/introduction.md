# デモユースケース: 複数リージョン間トラフィック制御

## 概要

copy_to_emulated_env, [PNIユースケース](./../../../copy_to_emulated_env/doc/pni_te/introduction.md)をベースにしています。
* 送信元ASは単一ASです (同様)
* 送信元ASの内部を東京・大阪の2つのリージョンと捉えます

> [!NOTE]
> [multi_src_as_teユースケース](../multi_src_as_te/introduction.md)の前段に作成した実験用のユースケースです。

![situation](./fig/multi_region_usecase.drawio.svg)

## デモの流れ

1st phase → tk01の流入量の調整をする(減らす)

1. tk01側の流量が増える
2. tk01 で広報するprefix 抜く
3. IX(tk02)側に移る
4. emulated_asis との比較で減ってることの確認

2nd phase → tk02じゃなくてtk03に行ってほしい

1. tk02側の流量が増える
2. tk02 で広報するprefix 抜く (とりあえず。本当はprependとかでやるかもしれない)
3. tk03側に移る?
4. emulated-asis, tk01/02/03 の流量バランス比較

## ユースケースパラメタ

- region の導入
    - 外部ASトポロジ作る際には、あまり影響がないけど分けて扱えるようにしておく
        - core-router: core00 (RR)
        - region-core-router: core01,02
    - endpoint (iperf node) をどっちのregion coreに振り分けるかを設定するためにprefixes(flow data で使われるprefix)を記載している
- dest_asはpni_teそのまま
    - 特にいじらない→この場合、edgeが複数あるとedge-coreはiBGP fullmesh になる

```yaml
---
expected_traffic:
  original_targets:
    - node: edge-tk01
      interface: ge-0/0/3.0
      expected_max_bandwidth: 0.8e9 # bps (e9=Gbps)
  emulated_traffic:
    scale: 1e-2 # 1Gbps to 10Mbps
source_as:
  asn: 65550
  regions:
    - region: tokyo1
      prefixes:
        - 10.0.1.0/24
        - 10.0.2.0/24
      allowed_peers:
        - peer: 172.16.0.5 # edge-tk01
          type: pni
    - region: tokyo2
      prefixes:
        - 10.0.3.0/24
        - 10.0.4.0/24
      allowed_peers:
        - peer: 172.16.1.9 # edge-tk02
          type: ix
  preferred_peer:
    node: edge-tk01
    interface: ge-0/0/3.0
dest_as:
  asn: 65520
  allowed_peers:
    - 192.168.0.10
```
