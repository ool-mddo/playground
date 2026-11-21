# docs 索引

文書の関連は、ファイル名ではなく **front matter の `topic`** と、この索引で管理する。
運用ルールは末尾の「運用ルール」を参照。

## トピック別

| topic | spec (現行仕様) | plan | investigation | todo |
|---|---|---|---|---|
| `fhrp-tp` (VRRP/HSRP の TP アトリビュート) | [fhrp_termination_point_attributes](fhrp_termination_point_attributes.md) | [fhrp_termination_point_attributes](work/plans/fhrp_termination_point_attributes.md) | | |
| `conduit` (conduit topology / blueprint) | [networks_attributes](networks_attributes.md) | [conduit_blueprint_flag](work/plans/conduit_blueprint_flag.md), [ospf_cost_timer_from_config](work/plans/ospf_cost_timer_from_config.md), [conduit_tp_description](work/plans/conduit_tp_description.md), [blueprint_with_endpoints](work/plans/blueprint_with_endpoints.md) | [conduit_ospf_config_failure](work/investigations/conduit_ospf_config_failure.md) | [conduit_ospf_area_attributes](work/todo/conduit_ospf_area_attributes.md) |
| `fw-policy` (FW ノード属性・policy) | [firewall_node_attributes](firewall_node_attributes.md) | [fw_policy_application_list](work/plans/fw_policy_application_list.md), [netomox_fw_policy_rule_array](work/plans/netomox_fw_policy_rule_array.md) | | |
| `ns-convert` (名前空間変換テーブル) | [architecture](architecture.md) (フロー部) | [ns_convert_table_both_snapshots](work/plans/ns_convert_table_both_snapshots.md) | | |
| `netoviz2` | [netoviz2_data_format](netoviz2_data_format.md) | [netoviz2_profile_api](work/plans/netoviz2_profile_api.md), [netoviz2_docs_reorg](work/plans/netoviz2_docs_reorg.md) | | |
| `containerlab` | | [clab_topology_env_name_and_fw_links](work/plans/clab_topology_env_name_and_fw_links.md), [fw_failover_test](work/plans/fw_failover_test.md) | | |
| `state-conductor` | | | | [state_conductor_states_dir](work/todo/state_conductor_states_dir.md) |
| `apnoms-trial` | | [apnoms_trial_preservation](work/plans/apnoms_trial_preservation.md) | | |
| `demo-scripts` | | [candidate_model_ops_scripts_reorg](work/plans/candidate_model_ops_scripts_reorg.md) | | |
| `runtime-update` | | | [runtime_security_update_2026-11](work/investigations/runtime_security_update_2026-11.md) | |

## 未分類 (front matter 未付与)

- 設計メモ: [architecture.md](architecture.md), [design_notes/](design_notes/)

## 運用ルール

文書の先頭に YAML front matter を付ける。ファイル名は変えない (リンクを壊さないため)。

```yaml
---
topic: fhrp-tp        # 関連文書で共通のスラッグ (この索引の topic 列と一致させる)
type: plan            # spec | plan | investigation | todo
status: done          # draft | approved | in-progress | done | abandoned (spec は省略可)
related:              # 関連文書のパス (docs/ からの相対)
  - fhrp_termination_point_attributes.md
---
```

- `status: done` は「実装がリリース済み」を指す。残る確認事項 (未実施の検証など) は本文の状態記述に書く。
- `status` は本文中の状態記述と矛盾させない (どちらかを更新したら両方更新する)。
- 文書を新規作成・状態変更したら、この索引も更新する。
- 関連文書を探すときは `grep -rl "^topic: <slug>" docs/` を使う。
