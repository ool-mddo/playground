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
