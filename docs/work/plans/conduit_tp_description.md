# Plan: conduit topology の layer3 TP description を整合させる

(状態: 実装済み。model-conductor の TpDescriptionResolver 追加、spec 追加、README 追記、実環境で再生成して検証済み)

## 目的

conduit topology (`original_asis_conduit*` / `emulated_asis_conduit*`) の layer3 term-point の
`description` (`to_<対向ノード名>_<対向インタフェース名>`) を、**最終的に出来上がったトポロジの中で整合**させる。

## 現状確認 (対象: `topologies/mddo-fw/` の conduit1 / conduit2)

確認方法: layer3 の各 non-segment TP について、link の有無と description を検査
(検査スクリプトは本計画の「検証」に再掲)。

### original_asis_conduit1 (conduit2 も同傾向)

| 種別 | TP 例 | 現状 | 問題 |
|---|---|---|---|
| 土管化ルータ TP | `site-a-wan-zone-rt:eth1..3` (計 6 TP) | **description なし (nil)** | 全 TP で欠落 |
| FW TP (link あり) | `site-a-fw-1:ge-0/0/1.0` | `to_site-a-br-1_ge-0/0/3` | 対向 `br-1` は conduit に存在しない。正しくは `site-a-wan-zone-rt` の TP |
| FW TP (link なし) | `site-a-fw-1:ge-0/0/2.0` `ge-7/0/2.0` `ge-7/0/1.0` など | `to_site-a-cr-1_ge-0/0/0` 等 (元のまま) | 対向 (`cr-*`, `br-*`) がトポロジから消えているのに残っている (stale) |
| segment TP | `Seg_*:site-a-wan-zone-rt_eth1` | **なし** | original_asis では `to_<ノード>_<TP>` が入っている ([l3_data_builder.rb:200](../../../repos/netomox-exp/lib/topology_builder/l3_data_builder.rb)) ので欠落。conduit1 の 10 TP すべて |

件数: conduit1 は linked 10 TP (うち router 6 = 全て nil、FW 4 = 全て対向が誤り)、
link なし 12 TP (全て stale)。conduit2 は linked 8 / link なし 12 (全て stale)。
OSPF 層の TP には description 属性はないので対象外。

### emulated_asis_conduit1

`ns_convert` の `update_tp_description` ([namespace_converter.rb:207-218](../../../repos/netomox-exp/lib/convert_namespace/namespace_converter.rb))
が **link を辿って** description を再生成するため、link のある TP は自己整合している
(例: `site-a-wan-zone-rt:eth1.0` → `to_Seg-172.32.1.0-30_Ethernet1`、segment TP → `to_site-a-wan-zone-rt_eth1`)。
通常の `emulated_asis` も同じ形式 (`to_Seg-..._Ethernet1`) なので、これは既存仕様。

一方 **link を持たない TP は更新対象外** のため original のまま残り、
conduit1 では FW の 12 TP が stale (`to_site-a-cr-1_ge-0/0/0` 等。しかも名前空間変換前の original の名前)。

### 原因 ([layer3_conduit_builder.rb](../../../repos/model-conductor/lib/generate_conduit_topology/layer3_conduit_builder.rb))

- `build_router_conduit_tp` / `build_conduit_tp`: 属性を `ip-address` / `flag` / `fhrp` のみで新規作成するので
  **ルータ TP の description は引き継がれず nil**。
- `build_fw_conduit_nodes`: FW は TP 属性を `dup` するだけで、link 付け替え
  (br-* → wan-zone-rt) 後も **元の description を無修正で保持**。link を失った TP の description も残る。
- `build_segment_node`: segment TP は `{}` で作られ、description が **付かない** (original では付く)。

## 方針

**description は「conduit topology の link 構造が確定した後」に、link から導出して一括で設定する**
(個別の TP 追加/削除ロジックの中では作らない)。これにより TP を足す・外す・付け替える処理が
将来増えても整合が崩れない。

### 他ネットワークの調査結果 (multi-access segment の description)

`topologies/*/*` の layer3 で 3 endpoint 以上の segment を全検索した結果:

| ネットワーク | 機器 TP の description | segment TP の description |
|---|---|---|
| mddo-fw (p2p のみ) | config の description そのまま。segment を跳ばして対向機器/IF (`to_site-c-br-1_ge-0/0/1`) | `to_<自身が繋がる機器>_<その TP>` |
| mddo-bgp `original_asis` (6 台が 1 segment) | config 由来の自由記述で、segment 背後の **L2 スイッチ/ポート** (`to_SW-TK01_Ethernet1`, 一部 `SW-TK01_Eth3` と形式ばらつき)。L3 topology に無い機器を指す | 同上 |
| mddo-bgp `emulated_asis` | ns_convert の `update_tp_description` により **segment を対向とする** (`to_Seg-192.168.1.0-24_Ethernet1`)。link 由来なので完全に整合 | 同上 |
| nttcom-trial `original_asis` | config 由来。L2 スイッチ `a01c.chib` の L3 TP (Vlan) を指す (`to_a01c.chib_Hu1/0/28`)。ハブ側 TP は config 由来の自由文 (`Chiba-minato BackBone #1`) | 同上 |
| mddo-mregnw / pushed_configs / batfish-test (L2 含む) | **空** (config に description なし。builder は `''` を設定) | 同上 |

結論:
- p2p: 機器 TP は segment を跳ばした対向 (config の規約)。
- multi-access: original 系に **生成ルールは無い**。config に書かれていればそのまま (対向が一意でないため L2 スイッチ等の背後機器を指す)、
  無ければ空。emulated 系だけが「segment を対向」とする link 由来ルールを持つ。
- segment TP は常に `to_<segment に繋がる機器>_<その TP>` (original / emulated 共通)。

### 規約 (ユーザ回答を反映した確定案)

- **p2p (2 endpoint の segment) の機器 TP**: `to_<対向ノード>_<対向 TP>` (conduit のノード名・TP 名、segment は跳ばす)。
  例: `site-a-wan-zone-rt:eth2` → `to_site-a-fw-1_ge-0/0/1.0`、`site-a-fw-1:ge-0/0/1.0` → `to_site-a-wan-zone-rt_eth2`。
  original_asis は TP 名が `ge-0/0/1` のように unit なしの config 由来だが、conduit 内の TP 名は topology 上の TP 名
  (`ge-0/0/1.0`, `eth2`) に統一する (整合性を topology 内で取るため。確認済み)。
- **multi-access (3 endpoint 以上の segment) の機器 TP**: 他ネットワークの original 系に生成規約がなく、
  対向が一意に決まらないので **生成しない**。conduit 化前の description も stale になりうるため **空にする**
  (mddo-mregnw 等の既存挙動と同じ)。warn ログを出す。
  ※ 現状の mddo-fw blueprint の external segment は全て p2p なので当面は発生しない。
- **link なしの TP** (FW の対向消滅分、HA ペアの片側 (fw-2 の ge-0/0/1 等)、fhrp edge TP): **空にする** (ユーザ確認済)。
- **segment TP**: `to_<conduit_node>_<conduit_tp>` を設定 (original の builder と同じ形式。`tp-id` は `<node>_<tp>` なので
  node/tp 名はその分解でなく link の対向 TP を使う)。

### 変更箇所

1. **model-conductor** [layer3_conduit_builder.rb](../../../repos/model-conductor/lib/generate_conduit_topology/layer3_conduit_builder.rb)
   - `assemble_conduit_layer3` で `conduit_nodes` / `conduit_links` が出揃った後に
     `TpDescriptionResolver` (新規、`fhrp_gateway_resolver.rb` と同様の独立クラス) を適用:
     1. conduit links から `[node, tp] → segment endpoint` の隣接表を作る
     2. non-segment ノードの各 TP について上記規約で `description` を設定 / 除去
     3. segment ノードの各 TP に `to_<対向機器>_<対向 TP>` を設定
   - 対象は FW・ルータ・fhrp edge TP (link なし) の全 TP。
   - 元トポロジのハッシュを破壊しない (FW は `dup` が浅いので、`L3_TP_ATTR` を新しい Hash に作り直してから書き換える)。
   - rubocop (`Metrics/ClassLength` は既に disable 済) に注意し、ロジックは新クラス側に置く。
2. **netomox-exp** (`update_tp_description`): **原則変更しない**。1 により入力に stale が無くなるため、
   emulated 側も自動的に整う。`update_tp_description` を「link なしは description 除去」に変えると
   通常の `emulated_asis` (config 由来の description を持つ link なしポート) の挙動まで変わるので避ける。
3. **テスト** `repos/model-conductor/spec/generate_conduit_topology/`
   (`layer3_conduit_builder_spec.rb`, `layer3_conduit_builder_fhrp_spec.rb`, `spec/support/fhrp_conduit_helpers.rb`):
   - ルータ TP に `to_<peer>_<peer tp>` が入る (router↔router, router↔FW)
   - FW の付け替え後 TP が新しい対向 (土管ノード) を指す
   - link のない FW TP / fhrp edge TP の description が除去される
   - 3 endpoint segment では機器 TP の description が空になる (warn)
   - segment TP に `to_<機器>_<TP>` が入る
   - 全 TP について「description が指すノード・TP が topology 内に実在し、その対向 TP の link と一致する」不変条件
4. **ドキュメント**: [README_refocus_topology.md](../../../demo/candidate_model_ops/README_refocus_topology.md)
   または `docs/design_notes/` に description 規約 (original: segment を跳ばす / emulated: segment を含む) を追記。

## 検証

1. `bundle exec rspec` / `rubocop` (repos/model-conductor)
2. `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh` で再生成
3. `original_asis_conduit*` / `emulated_asis_conduit*` に対し不変条件チェック:
   - link あり TP: description == `to_<対向>_<対向TP>` (original 系。segment TP は対向機器)
   - link なし TP: description なし (stale 0 件)
   - emulated 系: link あり TP は `update_tp_description` の結果と一致、stale 0 件
   (現状確認に使った検査 Ruby を `demo/` か spec に整理して再利用)
4. `./22_up_conduit.sh -s emulated_asis_conduit1 -d` で生成される config の interface description を目視確認

## 確認事項

すべて回答済み (実装待ち):
- p2p は original_asis 同様 (segment を跳ばす)。TP 名は topology 上の名前 (`ge-0/0/1.0`, `eth2`) に揃える。
- multi-access (3 endpoint 以上) の機器 TP は空 + warn。
- link なし TP (HA 片側含む) は空。

## リスク

- `ceos.j2` は description を無条件に出力するため、ceos ノードで description 空/欠落になると
  `description` 行が空になる。conduit のルータ/FW は crpd / vsrx だが、実装時に ceos 利用有無を確認する。
- netoviz が description を表示/参照していないか実装時に確認 (参照があれば nil/除去の扱いを確認)。

## 追加仕様: FW cluster pair の description 同一化 (実装済み)

- ge-0/0/X は primary、ge-7/0/X は secondary のインタフェースで、pair の両ノードは同名 TP を持つ (同一インタフェース)。
  片方のノードでのみ link があるので、link で確定した description を link のない側の同名 TP にコピーする。
- original 側: model-conductor `TpDescriptionResolver#sync_cluster_pairs` (node の `firewall.pair` から pair を特定)
- emulated 側: netomox-exp `NamespaceConverter#sync_firewall_pair_description` (通常の `emulated_asis` にも適用。
  fixture `emulated_asis.topology.json` の 4 TP の description が `to_Seg-...` に変わる)

## 追加修正: emulated 側も p2p は segment を跳ばす (実装済み)

当初 emulated 側 (netomox-exp `update_tp_description`) は link の直結先 (segment) を対向としていた
(`to_Seg-172.16.1.0-30_Ethernet1`)。原則 (p2p は segment の先の router/firewall の IF を指す) に反するため、
2 endpoint の segment は反対側の endpoint を対向にするよう修正。3 endpoint 以上は一意に決まらないので従来どおり segment 自身。
通常の `emulated_asis` にも適用される (fixture `emulated_asis.topology.json` の layer3 description が更新される)。

ノード種別ごとの規則 (original / emulated 共通):
router/firewall の p2p TP = segment の先の機器 TP、segment TP = 接続先機器 TP、link なし = 空 (FW cluster pair は同名 TP をコピー)。

## 修正サマリ (リポジトリ別の変更対象と内容)

コミットは未実施。変更したのは model-conductor と netomox-exp、および playground 側の README / plan。

### model-conductor (conduit topology 生成側 = original 系)

| ファイル | 内容 |
|---|---|
| `lib/generate_conduit_topology/tp_description_resolver.rb` (新規) | 生成した conduit layer3 の link 構造から description を作り直すクラス |
| `lib/generate_conduit_topology/layer3_conduit_builder.rb` | `build` 内で組み立て後に上記クラスを呼ぶ (+4 行) |
| `spec/generate_conduit_topology/tp_description_resolver_spec.rb` (新規) | 単体テスト |
| `spec/generate_conduit_topology/layer3_conduit_builder_spec.rb` | description 整合性チェックを追加 |

`TpDescriptionResolver` の設定内容:

- 機器 TP (2 endpoint の segment 経由): segment を跳ばして `to_<対向ノード>_<対向TP>` (TP 名は topology 上の名前、例 `ge-0/0/1.0`)
- 機器 TP (3 endpoint 以上の segment 経由): 空 + warn
- link なしの TP: 空。元トポロジの description は引き継がない
- segment TP: `to_<接続先機器>_<TP>`
- FW cluster pair: `firewall.pair` の primary/secondary で同名 TP を対応づけ、link で確定した description を link のない側へコピー

### netomox-exp (namespace 変換 = emulated 系)

| ファイル | 内容 |
|---|---|
| `lib/convert_namespace/namespace_converter.rb` | 下記 2 点 |
| `spec/convert_namespace/namespace_converter_spec.rb` | p2p の対向と pair 同一化のテストを追加 |
| `spec/fixtures/topologies/mddo-fw/emulated_asis.topology.json` | ゴールデン更新 (差分は layer3 の description のみ) |

`namespace_converter.rb` の変更:

1. `update_tp_description` の修正: 2 endpoint の segment は跳ばして反対側の機器/IF を対向にする。3 endpoint 以上は従来どおり segment 自身。修正前は常に直結の segment を指していた
2. `sync_firewall_pair_description` の追加: FW pair の同名 TP のうち link があるのが片側だけなら、その description をもう片側へコピー

### playground 側

- `demo/candidate_model_ops/README_refocus_topology.md`: description 規約の節を追記
- `docs/work/plans/conduit_tp_description.md` (本ファイル): 調査結果・方針・追加仕様・追加修正・本サマリ
- `topologies/mddo-fw/`: `21_generate_conduit.sh` で再生成済み (自動生成物)

### 影響範囲の注意

- netomox-exp の変更は conduit 専用ではなく、すべての emulated 変換に適用される。通常の `emulated_asis` の description も変わる。
- 変更後の挙動は mddo-fw で確認済み。mddo-bgp など他ネットワークは再生成しておらず、反映後の挙動は未確認。
- 未確認事項: `ceos.j2` の description 出力、netoviz の description 参照、`22_up_conduit.sh -d` での config 目視確認。
