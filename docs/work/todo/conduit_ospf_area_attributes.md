# TODO: conduit topology で OSPF area のネットワーク属性が欠落する

## ステータス

対応済み（model-conductor の conduit 生成とテンプレートを修正）。詳細は [investigation_conduit_ospf_config_failure.md](../investigations/conduit_ospf_config_failure.md) を参照。

## 症状

`emulated_asis_conduit1`（`original_asis_conduit1` を名前空間変換したもの）を `22_up_conduit.sh` で起動すると、
ansible-eda 側の `controller.yaml` の "generate ospf config" タスクが以下のエラーで失敗する:

```
'dict object' has no attribute 'identifier'
offending line: "generate ospf config"
```

該当テンプレート [demo/candidate_model_ops/playbooks/template/crpd/ospf/crpd_ospf.j2](../../../demo/candidate_model_ops/playbooks/template/crpd/ospf/crpd_ospf.j2) 呼び出し元の
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

## 影響範囲（修正前）

- `22_up_conduit.sh -s emulated_asis_conduit1` / `emulated_asis_conduit2` で
  ansible-eda 経由の config 生成が OSPF エリア関連のところで失敗していた。
- `emulated_asis`（非 conduit）には影響しなかった。

## 対応結果

- 原因調査・修正内容は [investigation_conduit_ospf_config_failure.md](../investigations/conduit_ospf_config_failure.md) を参照。
- 修正後の確認（2026-10-03）: `21_generate_conduit.sh` の後、`22_up_conduit.sh -s <snapshot> -d` を
  `emulated_asis` / `emulated_asis_conduit1` / `emulated_asis_conduit2` で実行し、
  いずれも ansible-eda の playbook が `failed=0` で完走（"generate ospf config" 以降も成功）。
  FW 以外の全ルータの conf に `router-id` が出力され、全 conf に OSPF area が含まれることを確認。
- 他のネットワークレベル属性（BGP proc 等）の conduit 化での欠落の横展開確認は、今回未実施
  （`refocus_topology` / `mddo-fw` には bgp_proc layer がない）。
