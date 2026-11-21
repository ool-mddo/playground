# profiles (ダイアグラムプロファイル)

netoviz2 の **schematic レイアウト** (`?layout=schematic`) で、トポロジを構成図として配置するための定義 (YAML) の**正本**を置きます。
トポロジとは別に、人が書き、git で管理します (`topologies/` は自動生成なので使いません)。

- 置き場所: `profiles/<network>/<名前>.yaml` (1 ファイルに複数のプロファイルを `---` 区切りで書けます)
- どの snapshot・レイヤに適用するかは、プロファイル自身の `target` (`network` / `snapshot` (正規表現) / `layer`) で宣言します。
- 配信: netomox-exp が読み、JSON に変換して `GET /topologies/:network/netoviz2/profiles` で返します ([API 仕様](../docs/netoviz2_data_format.md))。netoviz2 は YAML を読みません。JSON で表せない書き方 (アンカー・エイリアス・タグ) は使わないでください。
- 書式、選択の規則、設計: netoviz2 のドキュメント
  - [書式](../repos/netoviz2/docs/design/profile_format.md)
  - [schematic レイアウトの設計](../repos/netoviz2/docs/design/schematic_layout.md)

> 経緯と設計: [netoviz2_profile_api.md](../docs/work/plans/netoviz2_profile_api.md)。直したら、netomox-exp は毎回ファイルを読むので、netoviz2 をブラウザで再読み込みすれば反映されます (コピーの同期は不要)。

## 置いてあるプロファイル

| ファイル | 内容 |
|---|---|
| `mddo-fw/asis.yaml` | mddo-fw (3 拠点の FW 構成)。拠点が左右、br → fw → cr → seg → host が上下、1 と 2 が冗長ペア。自動で選ばれる |
| `mddo-fw/asis_y.yaml` | mddo-fw の Y 字配置 (別案)。DC (site-a) を中央の縦列、拠点 (site-b / site-c) を上の左右に置く。`asis.yaml` の後に選ばれるので自動では使われず、`?layout=schematic&profile=asis_y` で指定する |
| `mddo-bgp/asis.yaml` | mddo-bgp (emulated_asis の layer3)。自 AS (AS65518) を中央の縦列、上流 AS (AS65550 / AS65560) を上の左右、下流 AS (AS65520) を自 AS の下に置く Y 字 |

対称な配置 (Y 字など) に使うキー (netoviz2 v0.4.0 以降): 規則の `group: { value: ... }` (名前に依らず同じ列にする)・`align: center` (列の中を左右対称にする)、最上位の `symmetry` (列どうしを鏡像にする)・`keepEmptyTiers` (ノードの無い階層を空の行として残す)。書式は [netoviz2 の書式](../repos/netoviz2/docs/design/profile_format.md) を参照してください。
