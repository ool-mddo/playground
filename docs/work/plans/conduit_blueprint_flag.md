# Plan: conduit topology に生成元 blueprint を示すメタデータを付記する

(状態: 実装済み。netomox v0.14.1 を公開、netomox-exp / model-conductor のイメージに組み込み、実環境 (blueprint1 / 2) で確認済み)

## 目的

`21_generate_conduit.sh -b <blueprint_snapshot>` で生成される conduit topology
(`original_asis_conduit*` / 名前空間変換後の `emulated_asis_conduit*`) は、blueprint1 から作っても
blueprint2 から作っても同じ snapshot 名になる。生成元 blueprint がデータ上わからないため、
`ietf-network:networks` 直下(一番上のコンテナ)にメタデータとして付記する。

## 決定事項 (ユーザー確認済み)

- 付記場所: `ietf-network:networks` 直下
- RFC8345 の `networks` コンテナは leaf を持たず、素の `flag` を置くと YANG 非適合。
  独自拡張として **名前空間付き** にする。名前空間は既存の `mddo-topology` (`NS_MDDO`) を使う。
- キー: `mddo-topology:networks-attributes` (既存の `mddo-topology:l3-network-attributes` 等と同じ流儀)
- その中の JSON キーは `flag`、内部実装 (Ruby) の名前は `flags` (既存 `ATTR_DEFS` の `{int: :flags, ext: 'flag'}` と同じ)
- 値の形式: `blueprint=<blueprint snapshot 名>` (既存の `region=<name>` `ebgp-peer=...` と同じ `key=value` 形式)
- 実装は netomox gem 側から修正する

## データのイメージ

```json
{
  "ietf-network:networks": {
    "mddo-topology:networks-attributes": {
      "flag": ["blueprint=original_asis_blueprint1"]
    },
    "network": [ { "network-id": "layer3", ... }, ... ]
  }
}
```

属性が空 (`flags` が空) のときは出力しない (既存 attribute の `empty?` と同じ扱い)。

## 現状 (調査結果)

- `Netomox::Topology::Networks` は `TopoObjectBase` を継承しており `attribute` accessor は継承しているが、
  `initialize` で設定せず `to_data` にも出力しない (`topology/networks.rb`)。
  `Network` 側は `setup_attribute(data, ATTR_KEY_KLASS_LIST)` と `add_supports_and_attr` で扱っている。
- `DSL::Networks#topo_data` / `PseudoDSL::PNetworks#interpret` も `network` 配列のみ。
- `NetworkAttributeBase` (Topology / DSL) は `name` と `flags` を持つ。`PLURAL_ATTR_KEY_TABLE` に `flag: :flags` がある。
- model-conductor の `ConduitTopologyGenerator#build_conduit_topology` は
  `{'ietf-network:networks' => {'network' => [...]}}` のみ生成し、`blueprint_snapshot` は生成器に渡っていない
  (API 層 `conduit_topology.rb` で blueprint 取得にだけ使用)。
- netomox-exp の `convert_namespace` は `PNetworks` を新規作成して再構築するため、
  `networks` 直下の情報は gem 側で保持しない限り名前空間変換で失われる
  (`namespace_converter.rb` の `convert`、`rewrite_network`)。

## 変更方針 (段階的に実装。各段階でテストを実行)

### Step 1: netomox gem (`/home/hagiwara/ool-mddo/netomox`)

1. `topology/network_attr/mddo.rb` (または新規ファイル) に `MddoNetworksAttribute < NetworkAttributeBase` を追加。
   `name` は持たせず `flags` のみにするか、`NetworkAttributeBase` を継承して `name` を空のまま許容するかを実装時に決める
   (既存 `NetworkAttributeBase` は `name`/`flag` の両方を出力する。`name` が空なら出力しない方針に揃える)。
2. `topology/networks.rb`:
   - `ATTR_KEY_KLASS_LIST = [{key: "#{NS_MDDO}:networks-attributes", klass: MddoNetworksAttribute}]` を定義し、
     `initialize` で `setup_attribute` を呼ぶ。
   - `to_data` に `add_supports_and_attr` 相当で `networks-attributes` を出力 (空なら出さない)。
3. `dsl/network_attr/mddo.rb`: DSL 側 `MddoNetworksNWAttribute` を追加。
   `dsl/networks.rb`: `attribute` メソッド (DSL 記述用) を追加し、`topo_data` に出力。
4. `pseudo_dsl/p_networks.rb`: `attribute` accessor を追加し、`interpret` で `@nmx_networks.attribute(...)` に渡す。
5. `convert_attr.rb`: `Netomox.convert_attr_topo2dsl` が新 attribute を扱えることを確認 (`flag: :flags` は既存テーブルで対応済みのはず)。
6. `const.rb`: 必要なら定数 (属性キー名) を追加。
7. diff: `Networks#diff` に attribute の差分を含めるかは **初期スコープ外** とし、
   既存挙動 (networks 直下の attribute は diff 対象外) を維持する。必要になったら別途検討する。
8. spec 追加: JSON → `Networks` → `to_data` のラウンドトリップ、空の場合に出力されないこと、
   DSL / PseudoDSL からの出力、`convert_attr_topo2dsl` の変換。
9. `version.rb` を上げて gem を公開する。手順は [docs/design_notes/development.md](../../design_notes/development.md#netomox-gem-の修正を伴う開発) を参照。
   公開までの間は `docker-compose.override.yaml` でローカル netomox を netomox-exp / model-conductor に bind mount して開発する。

### Step 2: netomox-exp (`repos/netomox-exp`)

- `convert_namespace/namespace_converter.rb` の `convert` で、元トポロジの `networks` attribute (flags) を
  変換後の `PNetworks` に引き継ぐ (`original_asis_conduit*` → `emulated_asis_conduit*`)。
- 同様に `networks` を再構築している他の経路 (`upper_layer3_filter.rb` など) も確認し、必要なら引き継ぐ。
- spec: `namespace_converter_spec` に「networks 直下の flag が変換前後・backward 変換で保持される」ケースを追加。
- Gemfile / Gemfile.lock の netomox バージョンを更新。

### Step 3: model-conductor (`repos/model-conductor`)

- `lib/api/conduct/network/snapshot/conduit_topology.rb`: `ConduitTopologyGenerator.new` に `blueprint_snapshot` を渡す。
- `lib/generate_conduit_topology/conduit_topology_generator.rb`:
  `build_conduit_topology` の戻り値の `ietf-network:networks` に
  `'mddo-topology:networks-attributes' => { 'flag' => ["blueprint=#{blueprint_snapshot}"] }` を追加。
- spec: `conduit_topology_generator` の spec に、blueprint 名が flag に入ることの検証を追加。
- Gemfile / Gemfile.lock の netomox バージョンを更新 (model-conductor は topology の読み書きで netomox を使用する場合のみ)。

### Step 4: 確認とドキュメント

- topology store (netomox-exp の保存・取得 API) と netoviz が `networks` 直下の未知キーを
  破壊・拒否せず通すことを実機で確認する (netoviz は別リポジトリなので表示/エラーの有無を確認)。
- 実環境で `./21_generate_conduit.sh -b original_asis_blueprint1` / `-b original_asis_blueprint2` を実行し、
  `original_asis_conduit*` と `emulated_asis_conduit*` の `topology.json` に flag が入ることを確認する。
- 更新するドキュメント:
  - `demo/candidate_model_ops/README_refocus_topology.md` (conduit の生成元 blueprint の確認方法)
  - `repos/model-conductor/CLAUDE.md` (`conduit_topology` API の出力)
  - `repos/netomox-exp/CLAUDE.md` (名前空間変換で networks attribute を引き継ぐこと)
  - 新しい属性の canonical definition を `docs/` 配下に追加 (`firewall_node_attributes.md` と同様の形式)
  - `docs/architecture.md` に必要なら追記

## 影響範囲・注意点

- netomox gem の公開が必要 (利用側 model-conductor / netomox-exp / その他 gem 利用リポジトリのバージョン更新を伴う)。
- 既存のトポロジ JSON は `networks-attributes` を持たないため、読み込み・出力の互換性は維持される (空なら出力しない)。
- `_diff_state_` は `networks` 直下に出力される既存の独自キー。今回のキーと干渉しないことを spec で確認する。
- 既存インタフェースは変更しない (キーの追加のみ)。

## 未確認事項 (実装前/実装中に確認)

- `fetch_topology_data` / `post_topology_data` (MddoRestApiClient) と netomox-exp の保存 API が `networks` 直下の追加キーを保持するか。
- netoviz が `ietf-network:networks` の未知キーを許容するか。
- `MddoNetworksAttribute` に `name` を持たせるか (flags のみにするか)。
- 複数 blueprint の組み合わせ等で flag の値を複数持つ必要があるか (現状は 1 要素を想定)。
