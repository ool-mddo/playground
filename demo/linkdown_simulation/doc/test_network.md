# 開発用テストネットワークの分析

playground には開発用に使用するテストデータ ([batfish-test-topology](https://github.com/corestate55/batfish-test-topology)) のコンフィグが同梱されています。開発用のデータについては以下のようにトポロジデータを生成することで netoviz で確認可能になります。

```bash
# in playground/demo/linkdown_simulation dir
bundle exec mddo-toolbox generate_topology -n batfish-test-topology -p
```

> [!WARNING]
> - network = batfish-test-topology には複数の物理 snapshot が含まれています。 `-p` (`--phy-ss-only`) をつけないと、各物理スナップショットそれぞれに対してリンクダウンパターンを生成します。
> - 特定の物理スナップショットを指定する ( `-s` / `--snapshot`) ことで、1つのスナップショットに対してリンクダウンパターンを生成できます。

それぞれの物理スナップショットの目的

- ネットワーク構成については表中の参考リンクまたは [github README](https://github.com/corestate55/batfish-test-topology) を参照してください

| Snapshot | Description | Reference |
| --- | --- | --- |
| l2_sample3 | L2構成 (2switch, 2vlan) | [BatfishでL2 Topologyを出せるかどうか調べてみる (2) - Qiita](https://qiita.com/corestate55/items/bfac369b3f4532e5acef) |
| l2_sample4 | L2構成 (2switch, 2vlan, 1VRF) | 同上 |
| l2_sample5 | L2構成 (sample4 + 同一L2/異なるVLAN IDでの接続) | 同上 |
| l3_sample1a | L3構成, (複数 OSPF area, BGP, BGP対向再現) | [Batfish を使ってネットワーク構成を可視化してみよう・改 - Qiita](https://qiita.com/corestate55/items/fb18066d1105010758d9) |
| l3_sample1b | L3構成, (複数 OSPF area, BGP) | 同上 |
| l2l3_demo1 | L2_sample3 + ルータ (正常系) |  |
| l2l3_demo1a | L2_sample3 + ルータ (異常系: L3 IP重複, 複数prefix混在セグメント) |  |
| l2l3_demo1b | L2_sample3 + ルータ (正常系, スイッチ間ループ) |  |
| l2l3_demo1c | L2_sample3 + ルータ (異常系, スイッチ間クロス(同一L2/異VLAN ID)) |  |
| l2l3_demo1d | L2_sample3 + ルータ (正常系, Standalone L2 segment) |  |
| l2l3_sample3 | L2_sample3 + ルータ (正常系) |  |
| l2l3_sample3err | L2_sample3 + ルータ (異常系: 複数prefix混在セグメント) |  |
| l2l3_sample3err2 | L2_sample3 + ルータ (異常系: L3 IPアドレス重複) |  |
| l2l3_sample3err3 | L2_sample3 + ルータ (異常系: L2ループ) |  |
