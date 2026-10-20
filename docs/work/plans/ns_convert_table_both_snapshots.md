# Plan: ns_convert_table を original / emulated 両方の snapshot に保存する

(状態: 調査のみ。コードは未修正。指示があるまで修正しない)

## 現状

- netomox-exp: `ns_convert_table.json` は `topologies/<nw>/<ss>/` に per-snapshot で保存される。
  `POST /topologies/:nw/:ss/ns_convert_table` は
  - body 空 / `usecase` → `:ss` の `topology.json` からテーブルを生成して保存
  - `convert_table` → 渡されたテーブルをそのまま `:ss` に保存
- model-conductor `POST /conduct/:nw/ns_convert/:src_ss/:dst_ss`
  ([ns_convert.rb](../../../repos/model-conductor/lib/api/conduct/network/ns_convert.rb)):
  1. `table_origin` 指定あり → `post_init_ns_convert_table(network, origin_ss, usecase)`
     (= origin snapshot ディレクトリにのみ保存)
  2. `table_origin` 指定なし → `exist_ns_convert_table!(network, src_ss)` で src 側の存在確認のみ
  3. `fetch_converted_topology_data(network, src_ss)` → `post_topology_data(network, dst_ss, ...)`
  - → dst (emulated) 側にはテーブルが存在しない (現状 `topologies/mddo-fw/` には `original_*` のみ)
- shell: `convert_namespace()` ([util.sh:30-42](../../../demo/candidate_model_ops/scripts/util.sh))
  が `table_origin=$src_ss` を付けて上記 API を呼ぶ。

## 方針

**テーブルの中身は変えず、変換完了時に dst_ss にも同一内容を保存する。**
テーブルは origin (original) トポロジから生成された 1 枚 (`node_name_table` /
`tp_name_table` / `ospf_proc_id_table` / `static_route_tp_table`) で、
`reverse_lookup` により逆引きも可能なので、方向別に別内容を作る必要はない。
netomox-exp 側の API は既に任意 snapshot への `convert_table` POST を受け付けるため、
**netomox-exp のコード変更は不要**。変更は model-conductor の `ns_convert` API に集約する。

## 変更箇所

### 1. 必須: [repos/model-conductor/lib/api/conduct/network/ns_convert.rb](../../../repos/model-conductor/lib/api/conduct/network/ns_convert.rb)

`post 'ns_convert/:src_ss/:dst_ss'` の末尾 (`post_topology_data` の後) に追加:

```ruby
converted_topology_data = rest_api.fetch_converted_topology_data(network, src_ss)
rest_api.post_topology_data(network, dst_ss, converted_topology_data)

# save the same convert table to destination snapshot (table is stored in both of src/dst snapshots)
ns_convert_table = rest_api.fetch_ns_convert_table(network, src_ss)
rest_api.post_update_ns_convert_table(network, dst_ss, ns_convert_table)
```

- `table_origin` 指定あり/なしの両分岐の後に共通で実行される。
  - 指定あり: `origin_ss` に再生成された表を `src_ss` から取得して `dst_ss` に複製。
    (`table_origin` ≠ `src_ss` の場合、`src_ss` の表は `origin_ss` で再生成されたものではないので、
    `fetch` 元は `src_ss` ではなく **`table_origin` があればそれ、なければ `src_ss`** にする。
    例: `table_ss = origin_ss || src_ss`)
  - 指定なし: `src_ss` の既存表を複製 (demo_step4 の `emulated_tobe` → `original_tobe` の場合は
    src=emulated 側に表が必要。下記 §4 参照)。
- 順序: dst の topology POST の後に実行 (topology POST はディレクトリ作成のみで表は消さないが、
  意図を明確にするため後置)。
- `fetch_ns_convert_table` は `symbolize_names: false` 済みで、`post_update_ns_convert_table` は
  JSON でそのまま送れる (`DO NOT symbolize` 注意 ([CLAUDE.md](../../../repos/model-conductor/CLAUDE.md)) を遵守)。
- ログ: `logger.info "Copy ns convert table of network:#{network} from #{table_ss} to #{dst_ss}"` を追加。

### 2. 任意: [repos/model-conductor/lib/api/mddo_rest_api_client.rb](../../../repos/model-conductor/lib/api/mddo_rest_api_client.rb)

不要 (既存の `fetch_ns_convert_table` / `post_update_ns_convert_table` で足りる)。
ヘルパーとして `copy_ns_convert_table(network, from_ss, to_ss)` を追加してもよい (好み)。

### 3. 変更不要の確認済み箇所

- netomox-exp `lib/api/topologies/network/snapshot/ns_convert_table.rb`, `lib/api/helpers.rb`:
  既に per-snapshot / 任意 snapshot への保存対応。
- DELETE 系: original/emulated のペアで扱うのは **表の作成時のみ**。`DELETE /topologies/:nw/:ss` で
  単一 snapshot が削除されても、ペアの相手側 snapshot (とその表) は **そのまま残す** (同期しない)。
  現状の `rm_rf` 動作のままでよく、変更不要。
- `topology_ops.rb`: 次の `original_asis_preallocated(N+1)` に表を保存する。emulated 側は後続の
  `convert_namespace` (`table_origin` 付き) で表が再生成・複製されるため変更不要。
- `03_candidate_env.sh` / `02_benchmark_env.sh` / `11_manual_steps.sh` / `21_generate_conduit.sh`:
  すべて `convert_namespace` 経由なので API 修正で自動的に両側保存になる。
- ansible `controller.yaml` は `snapshot_name` (emulated snapshot) 側の `config_params` 等を参照する。
  emulated 側にも表が保存されるため 404 にならない。
- state-conductor `app.py:152` の旧 per-network URL は **今回は変更しない** (スコープ外)。

### 4. 確認・要判断事項

- **逆方向 ns_convert (emulated → original):** `demo/copy_to_emulated_env/demo_step4.sh`
  (`ns_convert/emulated_tobe/original_tobe`、`table_origin` なし) は src=`emulated_tobe` の表を要求する
  (`exist_ns_convert_table!`)。現状は emulated 側に表が無く 404 になるが、今回の変更で
  先に emulated 側に保存されるので解消する (この方向では dst にも複製)。
  ただし `demo/copy_to_emulated_env/` は旧デモで、現在のターゲット外。動作確認は不要か要判断。
- **表の内容は方向別に変えない (決定済み):** original/emulated に同一内容を保存する。
  CLAUDE.md 類の「`emulated_*` は emulated → original 方向」という記述は実装と乖離しているため、
  ドキュメント更新で「同一内容の表が両側に保存される」に修正する。
- **`reload` → `to_hash` の往復で内容が変わらないか:** `POST convert_table` は
  `NamespaceConverter#reload` → `to_hash` を通るので、original 側と emulated 側ファイルが
  バイト一致 (キー順含め) するか実機で一度 diff 確認する。

## ドキュメント更新

| ファイル | 修正内容 |
|---|---|
| [CLAUDE.md](../../../CLAUDE.md) L80-81 | `convert_namespace` が表を **original/emulated 両 snapshot ディレクトリ** に保存する旨を追記 |
| [docs/architecture.md](../../architecture.md) L227 | 「`original_*` 側にのみ存在」→ 両側に存在 (内容は同一)。ansible へは引き続き original 名を渡す理由の説明を修正 |
| docs/architecture.md L288 | フロー6 入力の `topologies/mddo-fw/ns_convert_table.json` → `original_asis/ns_convert_table.json` に訂正し、出力に `emulated_asis*/ns_convert_table.json` を追加 |
| docs/architecture.md L308 | 「一方向」注記に、表は両 snapshot に保存される旨を追記 |
| [repos/model-conductor/CLAUDE.md](../../../repos/model-conductor/CLAUDE.md) L119-135 | `ns_convert.rb での使用` に dst への複製ステップを追記 |
| [repos/netomox-exp/CLAUDE.md](../../../repos/netomox-exp/CLAUDE.md) L253-270 | 「変換方向の意味」表を実装に合わせて修正 (同一内容が両側に保存される) |
| repos/netomox-exp/docs/test_plan.md L76 | 「`original_*` / `emulated_*` の方向」の記述を実装に合わせて確認 (必要なら修正) |
| [demo/candidate_model_ops/README_refocus_topology.md](../../../demo/candidate_model_ops/README_refocus_topology.md) | ns_convert / 生成物一覧に emulated 側の `ns_convert_table.json` を追記 (該当記述がある場合) |

## テスト / 検証

- model-conductor に ns_convert API の spec は無い (`spec/` は topology_ops, generate_conduit_topology 等のみ)。
  `rest_api` を double にして「`post_update_ns_convert_table(nw, dst_ss, table)` が呼ばれる」ことを
  確認する spec の追加を検討 (`table_origin` あり/なし 2 ケース)。
- 実機: `docker compose up -d` → `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh`
  実行後に以下を確認:
  - `topologies/mddo-fw/{original,emulated}_asis/ns_convert_table.json` が存在し内容が一致
  - `{original,emulated}_asis_conduit*/ns_convert_table.json` も同様
  - `./22_up_conduit.sh -s emulated_asis -d` が従来どおり通る (config 生成確認)
  - `GET /topologies/mddo-fw/emulated_asis/ns_convert_table` が 200
- 単一 snapshot を `DELETE` しても相手側の表が残ること (同期しないこと) を確認する。
- 注意: `topologies/` は自動生成物なので直接編集しない (CLAUDE.md の制約)。

## 影響範囲まとめ

コード変更は `repos/model-conductor/lib/api/conduct/network/ns_convert.rb` の数行のみ
(+ 任意で spec とドキュメント)。netomox-exp / シェルスクリプト / ansible は変更不要。
