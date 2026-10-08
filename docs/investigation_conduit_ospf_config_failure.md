# 調査: conduit topology (emulated_asis_conduit{1,2}) のコンフィグ生成失敗

**ステータス: 実施済み**（A〜D の修正を適用し、conduit1/2 と emulated_asis で `22_up_conduit.sh -d` によるコンフィグ生成が完走することを確認。ABR 挙動の実機確認とテスト追加は未実施）
関連: [docs/todo_conduit_ospf_area_attributes.md](todo_conduit_ospf_area_attributes.md)（先行メモ。本調査で裏取り・拡張）

## 結論（要約）

失敗の直接原因は **conduit topology 生成ロジックのデータ欠落**（構造の参照切れではない）。
ただし「構造・意味が original_asis と整合しているか」の観点で見直すと、追加で **意味レベルの問題が 3 件** あった。

| # | 区分 | 内容 | 影響 |
|---|---|---|---|
| A | 欠落(直接原因) | ospf_area の `ospf-area-network-attributes`(identifier 等)と `supporting-network` が conduit に無い | "generate/merge ospf config" が `no attribute 'identifier'` で失敗。`vsrx_cluster.j2:137` も同様 |
| B | 欠落 | layer3 の `l3-network-attributes` が無い | 現 template では未使用。整合のため補完 |
| C | **順序**(意味) | conduit の ospf network 順が 20,10,0（`sort_ospf_networks`）。original は 0,10,20 | `crpd_routing-option-routerid.j2:3` が `ospf_nodes.json[0]["nodes"]` だけを見て router-id を出力。conduit1 では先頭が area20 で **site-a-wan-zone-rt の router-id が出力されない**（A 修正後に顕在化する第2の失敗/誤設定） |
| D | 意味(neighbor) | ospf TP の `neighbor.router-id` が統合前の旧 router-id のまま | 例: conduit1 `site-a-fw-2 ge-7/0/1.0` の neighbor=172.16.0.2 だが、統合後ルータの router-id は 172.16.0.1(代表=br-1)。conduit2 では site-b-fw-* の neighbor が 172.16.3.1/3.2 だが wan-zone-rt の rid は 172.16.0.1。現 template は未使用だが、モデルとして矛盾 |

## 根拠 A/B: データ比較（`topologies/mddo-fw/*/topology.json`）

| network | original_asis | original_asis_conduit1/2 (= emulated_* も同一) |
|---|---|---|
| ospf_area{0,10,20} | `supporting-network:[{layer3}]`, `ospf-area-network-attributes:{name,identifier,flag}` | 両キー無し |
| layer3 | `supporting-network:[{layer2}]`, `l3-network-attributes:{name,flag}` | 両キー無し |

API: `.../topology/layer_type_ospf/interfaces?node_type=ospf_proc` の `attribute` が original は `identifier:'0.0.0.20'`、conduit は `_diff_state_` のみ。

コード: `repos/model-conductor/lib/generate_conduit_topology/`
- `ospf_conduit_builder.rb#build` は `network-id/network-types/node/link` のみ生成
- `layer3_conduit_builder.rb#assemble_conduit_layer3` も同様
- `conduit_topology_generator.rb#sort_ospf_networks` が順序を決定（C の原因）

## 意味的整合性の検証結果（original_asis と conduit の突き合わせ）

構造（機械チェック）: 全 ospf node/TP が conduit layer3 に存在、supporting-TP 参照先あり、ospf link 端点あり、
ospf の Seg ノード TP 集合 == layer3 の同名 Seg TP 集合（conduit1/2 とも一致）。→ **構造は整合**。

意味（original との対応）:
- **IP/prefix**: 統合ルータの TP は元 TP の ip-address をそのまま保持（例 conduit1 site-a: eth1=172.16.1.1/30(br-1 ge-0/0/3), eth3=172.16.2.1/30(br-2 ge-0/0/3), eth2=172.32.0.1/30）。connected prefix も外部 TP のものだけ残り妥当。FW ノードは全 TP・IP・prefix をそのまま保持。→ OK
- **隣接関係(L3/OSPF の接続)**: FW↔ルータの各 /30 セグメントは original と同じ組合せ（br-1↔fw-1=172.16.1.0/30, br-2↔fw-2=172.16.2.0/30 等）。area 10/20 の ospf TP の area/metric/timer/network-type(BROADCAST/P2P) は original と一致。→ OK
- **設計上の簡略化（仕様どおり、要ドキュメント化）**: conduit1 では A–B 間の並行リンク(172.32.0.0/30, 172.32.2.0/30)が1本(172.32.0.0/30)に集約、br-1↔br-2 内部セグメント(172.16.0.0/30, 172.16.3.0/30)は消滅、未接続 IF(ge-0/0/1 等)は消滅。冗長性は conduit では失われる。
- **conduit2 の area0**: A–B が1ノードに統合され area0 は IF 0・link 0。ユーザー決定=「そのまま」。ただし area10/20 を持つ単一ルータが area0 の IF 無しで ABR として機能するか(エリア間経路が伝搬するか)は意味的に未確認 → 検証手順に追加（cRPD での確認、問題なら別途方針相談）。
- **router-id**: 統合ルータは代表(first)ノードの rid を使用（conduit1: 172.16.0.1/172.16.3.1, conduit2: 172.16.0.1）。これ自体は妥当だが D の neighbor 側が追従していない。
- **ospf Seg の重複排除**: layer3 と ospf で別々に「最初の1本」を選ぶ実装（`deduplicate_segments` / `process_segment_node`）。現データでは一致するが、順序依存で将来ずれうる（ospf 側が layer3 に無い Seg を作る）。→ 修正時に layer3 で残った Seg を ospf 側の基準にするのが堅い（今回は検出のみ、対応は検討事項）。

## ユーザー決定（追加論点）
1. conduit2 の空 `ospf_area0`: そのまま（除外しない）。ただし上記 ABR 挙動は検証で確認。
2. conduit layer3 の `supporting-network`: 空（付けない）。
3. 代表ノード属性流用: 可。
4. generator のテスト: 保留（今回は追加しない）。

## 修正方針（実施済み）

対象: `repos/model-conductor/lib/generate_conduit_topology/`（+ playbooks 1 ファイル）
1. **A** `ospf_conduit_builder.rb#build`: `'mddo-topology:ospf-area-network-attributes'` と `'supporting-network'`（ospf は layer3 が conduit にも存在するのでコピー可）を original から dup。定数 `OSPF_NW_ATTR` を追加。`.compact` により無い場合は出力されない。
2. **B** `layer3_conduit_builder.rb#assemble_conduit_layer3`: `'mddo-topology:l3-network-attributes'` を追加。`supporting-network` は付けない。
3. **C** 順序: 次のどちらか（推奨は両方）
   - `conduit_topology_generator.rb#sort_ospf_networks` を original と同じ area 昇順(0,10,20)に変更
   - `crpd_routing-option-routerid.j2` を `ospf_nodes.json[0]` 依存から「全 area を走査して当該ノードの router-id を出力（重複出力しない）」へ変更。順序非依存で堅牢（original 側の暗黙前提 area0 先頭も解消）
4. **D** `ospf_conduit_builder.rb`: ospf TP の `neighbor` を、`ip-address` が統合ノードの TP に属する場合、その conduit ノードの router-id に書き換える（node_mapping と代表ノードの ospf router-id から算出）。FW 共有 rid(172.16.1.2 等)は不変。
5. RuboCop (Metrics) に注意（メソッド分割）。

## 検証手順
1. `./21_generate_conduit.sh` 再実行（model-conductor は bind mount、再ビルド不要）。
2. Python で再チェック: ospf_area*/layer3 のネットワーク属性、ospf network 順、neighbor.router-id が統合後 rid と一致、構造チェック（上記）が引き続き OK。
3. `curl .../original_asis_conduit1/topology/layer_type_ospf/interfaces?node_type=ospf_proc` で `attribute.identifier` が返ること。
4. `./22_up_conduit.sh -s emulated_asis_conduit1 -d` / `-s emulated_asis_conduit2 -d` が完走。生成 conf で
   - `area 0.0.0.X`, interface 名(eth*)・metric・p2p/passive が original の対応 IF と一致
   - **全ルータに `routing-options { router-id ... }` が出る**（特に conduit1 の site-a-wan-zone-rt）
   - FW cluster conf の ospf area が正しい
5. 実起動(可能なら)で OSPF 隣接確立と、conduit2 で area10↔area20 の経路伝搬（ABR 挙動）を確認。
6. `emulated_asis`（非 conduit）に回帰が無いこと（template 変更の影響確認）。
7. `docs/todo_conduit_ospf_area_attributes.md` のステータス更新。
