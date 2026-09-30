# TODO: conduit topology で OSPF area のネットワーク属性が欠落する

## ステータス

未着手。別タスクとして対応予定。

## 症状

`emulated_asis_conduit1`（`original_asis_conduit1` を名前空間変換したもの）を `22_up_conduit.sh` で起動すると、
ansible-eda 側の `controller.yaml` の "generate ospf config" タスクが以下のエラーで失敗する:

```
'dict object' has no attribute 'identifier'
offending line: "generate ospf config"
```

該当テンプレート [demo/candidate_model_ops/playbooks/template/crpd/ospf/crpd_ospf.j2](../demo/candidate_model_ops/playbooks/template/crpd/ospf/crpd_ospf.j2) 呼び出し元の
`controller.yaml` の `generate ospf config` タスクは `item.0.attribute.identifier`（OSPF area の識別子、例: `0.0.0.20`）を参照するが、
conduit スナップショットの topology データにはこの属性が存在しない。

## 原因（調査済み）

`GET /topologies/mddo-fw/<snapshot>/topology` のレスポンスを比較すると:

- `original_asis`（非 conduit）: `ospf_area20` ネットワークオブジェクトに
  `mddo-topology:ospf-area-network-attributes`（`identifier: "0.0.0.20"` を含む）キーが存在する。
- `original_asis_conduit1`（conduit 化後）: 同じ `ospf_area20` ネットワークオブジェクトに
  このキー自体が存在しない（`supporting-network` キーも同様に欠落）。

つまり `21_generate_conduit.sh` の `generate_conduit_topology`（blueprint に基づく土管化処理。実体は
netomox-exp / model-conductor 側の conduit topology 生成ロジック）が、OSPF area の
ネットワークレベル属性（`mddo-topology:ospf-area-network-attributes`）を生成結果から落としている。

## 影響範囲

- `22_up_conduit.sh -s emulated_asis_conduit1`（および恐らく `emulated_asis_conduit2` も同様）で
  ansible-eda 経由の config 生成が OSPF エリア関連のところで失敗する。
- `emulated_asis`（非 conduit, `original_asis` 起動分）には影響しない（確認済み、正常動作）。

## 次のアクション（未実施）

1. `repos/netomox-exp` および `repos/model-conductor` の conduit topology 生成コード
   （`generate_conduit_topology` の実装）を調査し、OSPF area のネットワークレベル属性
   （`mddo-topology:ospf-area-network-attributes` および `supporting-network`）を
   コピー・再構築する処理が抜けていないか確認する。
2. 同様に他のネットワークレベル属性（BGP proc 等）についても conduit 化で欠落していないか
   横展開で確認する。
3. 修正後、`22_up_conduit.sh -s emulated_asis_conduit1 -d` を再実行し、
   `docker compose logs ansible-eda` で "generate ospf config" 以降のタスクが
   エラーなく完走することを確認する。
