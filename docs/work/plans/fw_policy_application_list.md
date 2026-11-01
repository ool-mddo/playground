# FW policy の `application` 複数指定 (リスト) 対応 plan

状態: **レビュー指摘 (M-1/M-2/L-2/L-5/テスト不足) 反映済み。Step 1, 2, 4 実装済み (未コミット)。Step 3 は netomox plan 側で実装済み。Step 6 は部分確認済み (下記)。**

進捗:
- Step 1 (firewall-policy-parser): TTP は各キーを `*` サブグループで収集、`ttp_parse()` でリスト記法を事前展開し結果を平坦化。pytest 11 件成功。
- Step 2 (docs): `docs/firewall_node_attributes.md` を Array[String] に更新。
- Step 3 (netomox 0.15.0): [netomox_fw_policy_rule_array.md](netomox_fw_policy_rule_array.md) 参照。
- Step 4 (j2): `vsrx_cluster.j2` に `junos_list` マクロを追加 (1 要素は `x`、複数は `[ x y z ]`、旧 String も可、空配列は `[  ]` となり vSRX の commit でエラーになる=黙って通さない)。
- Step 6 部分確認: 複数値入力 → パーサー → model-conductor コンテナ (ローカル netomox) で読み込み (ERROR ログなし) → j2 描画まで確認。
  `21_generate_conduit.sh` / `22_up_conduit.sh` のフル実行は未実施 (mddo-fw を変更しない方針のため、別 network の用意が必要)。

## 決定事項 (ユーザー回答)

1. 型は**常に配列** (案 A)。`any` も `["any"]`。
2. 対象は `application` に加え `source_address` / `destination_address` も**同時に対応** (3 項目とも `Array<String>`)。
3. `configs/mddo-fw` は**今回更新しない** (Step 5 は対象外。結合確認は一時的な入力で行う)。

以降の手順は上記に合わせて読み替える: Step 1〜4 は 3 項目すべてが対象、Step 5 はスキップ。
`address-book` / `address-set` は引き続き未対応 (名前の解決はしない。文字列のまま配列に入れるだけ)。

## 背景

`configs/mddo-fw/original_asis/configs/site-a-fw-1.config` の `PERMIT-PING-DNS-HTTPS` (L87-97) は現在 `application junos-ping;` のみ。
意図は ping / DNS / HTTPS を許可することで、次のように application をリストにする必要がある。

```
application [
    junos-ping
    junos-dns-udp
    junos-dns-tcp
    junos-http
    junos-https
];
```

JunOS ではリスト記法として次の 3 形式が有効。いずれも対応対象とする。

1. 複数行 `application [` / 1 行 1 要素 / `];`
2. 1 行 `application [ a b c ];`
3. 同一 match 内に `application a;` `application b;` を複数行

## 調査結果: 原因

### 1. パース (firewall-policy-parser) — 主因 (実行して確認済み)

`repos/firewall-policy-parser/src/template/juniper_srx.ttp` の rules グループが全てスカラー変数前提。

```
application {{ application }};
{{ action }};
```

実際に TTP を実行して確認した結果 (policy は `[` `]` 形式):

| 入力 | 結果 |
|---|---|
| 複数行 `application [ ...newline... ];` (policy A) | `application` キーが**欠落**。さらに `{{ action }};` が `];` 行にマッチし、`action: "]"` という**壊れた値**になる (本来の `permit` が失われる) |
| 1 行 `application [ a b ];` (policy B) | `application` キーが**欠落** (エラーなし、無音) |
| 同一 match 内の複数行 `application a;` `application b;` (policy C) | 最初の 1 つ (`junos-ping`) のみ残り、他は無音で捨てられる |

つまり現状は「リストを扱えない」だけでなく、**action が壊れる**ケースがある点が重要。
`parse_fw_policy.py` の `_build_output` は TTP 結果をそのまま出力に入れるため、ここでの正規化は無い。
既知の課題として `repos/firewall-policy-parser/docs/design-notes.md:41-43` と
`docs/reviews/2026-09-05-initial-design-review.md` F-1 (Open) に「同一 match の複数行は上書き/欠落」が記載済み。

### 2. スキーマ / 型定義

- canonical: `docs/firewall_node_attributes.md:136` で `policies[].rules[].application` は **String**。
- netomox gem (0.14.1, 本リポジトリ外): `topology/node_attr/mddo_l3_firewall_policy.rb` の `ATTR_DEFS` は `default: ''` (スカラー)、
  `dsl/node_attr/mddo_l3_firewall_policy.rb` の `initialize` も `application: ''`。YARD も `@return [String]`。
  アクセサは型強制をしていないため配列も素通りする可能性が高いが、**未検証** (要 spec で確認)。
- model-conductor `firewall_policy_patcher.rb:49-56` / netomox-exp は FW 属性を丸ごとコピーするだけで application を解釈しない → 修正不要の見込み。

### 3. エミュレーション用 config 生成 (トポロジ → config)

`demo/candidate_model_ops/playbooks/template/vsrx/vsrx_cluster.j2:57-59` が
`application {{ rule["application"] }};` と単一値で出力。リスト (Python list) を渡すと
`application ['junos-ping', 'junos-https'];` のように JunOS として不正な文字列になる (推測、未実行)。
`source_address` / `destination_address` (L57-58) も同じ作りだが、今回のスコープ外 (後述)。
呼び出し元は `playbooks/controller.yaml:169-182` (primary ノードのみ生成)。他に FW policy を出力する generator は見つかっていない。

### 4. その他

- playground 内に junos-* (junos-ping, junos-dns-udp 等) のプロトコル/ポート対応表は無い。application 名は全工程で不透明な文字列として扱われ、
  JunOS 組み込み名は emulated 側 (vSRX) がそのまま解釈する。名前を出力するだけの本要件では**対応表は不要**。
- `application-set` / `applications` 定義セクションは firewall-policy-parser で未対応 (既知)。今回は junos-* 組み込み名のみ想定のためスコープ外。

## 方針の選択肢 (要判断)

JSON 上の `application` の型について。

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| A (推奨) | 常に `Array<String>` (`"any"` も `["any"]`) | 型が一貫、利用側の分岐不要 | 既存 interface (String) の変更。既存 topology JSON / expects / docs / gem の更新が必要 |
| B | 単一なら String、複数なら Array | 既存データ互換 | 型が混在し、j2 や今後の利用側で分岐必須。TTP 側でも後処理が複雑 |
| C | 新キー `applications` (Array) を追加し `application` は残す | 既存 interface 維持 | 二重管理、`application` の意味が曖昧 |

CLAUDE.md の「明示的な承認がない限り既存 interface を維持」により、**A/B/C いずれも承認が必要**。以下の手順は A を前提に書く (B/C の場合は差分を調整)。

## 修正箇所と手順 (小さな単位に分割)

### Step 0: 事前確認 (変更なし)

- netomox gem で `application` に配列を渡しても `ATTR_DEFS` 経由で保持・出力されるか spec / irb で確認。
  問題があれば gem 側 (ool-mddo/netomox) の修正が前提になり、リリース手順 (`docs/design_notes/development.md`) が絡む。

### Step 1: firewall-policy-parser (サブモジュール `repos/firewall-policy-parser`)

1. `src/template/juniper_srx.ttp`
   - application を `*` 付きサブグループにして**リストで収集**する。1 行 `[ a b c ]` / 複数行 `[` ... `]` / 同一 match 内の複数行 `application x;` の 3 形式に対応。
   - `{{ action }};` が `];` や `[` 行、要素行にマッチしないようにする (`action` を `permit|deny|reject` に `re()` で限定、あるいは then ブロック内に絞る)。
   - TTP の複数マッチ挙動 (`_start_` / `_end_`、`ignore` 等) は実験しながら決める。実験用入力は上記の A/B/C ケース。
2. `src/parse_fw_policy.py` の `_build_output` で application を `list[str]` に正規化 (案 A)。`any` のみは `["any"]`。
3. `test/`: 3 形式 + 単一値の入力ケースを追加、`test/expects/*.json` を更新。
4. 関連 docs 更新 (`docs/design-notes.md` の既知制約、review F-1 の状態)。

### Step 2: スキーマ docs (playground 本体)

- `docs/firewall_node_attributes.md` (L59 の例、L136 の型) を `Array<String>` に更新。
- 型変更は複数リポジトリにまたがる canonical definition 変更なので承認を得てから実施。

### Step 3: netomox gem (Step 0 の結果次第)

- 型コメント (YARD) と DSL の default を `[]` にする必要があるか判断。必要なら別途リリースが必要。

### Step 4: config 生成 (playground 本体)

- `demo/candidate_model_ops/playbooks/template/vsrx/vsrx_cluster.j2:59` を、
  要素が 1 つなら `application x;`、複数なら `application [ a b c ];` で出力するよう変更
  (例: `{% if rule["application"] | length > 1 %}application [ {{ rule["application"] | join(" ") }} ];{% else %}...`)。
- 互換のため、値が文字列で来た場合も出力できるようにしておく (旧 topology JSON を読む場合の保険)。
- `source_address` / `destination_address` は今回スコープ外 (同様の問題があるが別 plan で扱う)。

### Step 5: 設定ファイル (サブモジュール `configs/mddo-fw`) — **今回は対象外 (決定事項 3)**

- `original_asis/configs/site-a-fw-1.config` (および site-a-fw-2 の対応 policy) の application を 5 要素のリストに更新。
  `emulated_asis` 側の config はテンプレート由来なので生成結果を確認して、手書きなら同様に更新。
- submodule 側でコミット → playground 側で参照先更新。
- 現在 `configs/mddo-fw` は `M` (作業中の変更あり) なので、扱い方を確認してから実施。

### Step 6: 結合確認

1. firewall-policy-parser 単体テスト (`test/test_parse.py`) 実行。
2. `demo/candidate_model_ops` で `21_generate_conduit.sh` → 生成 topology の `policies[].rules[].application` が配列になっていること。
3. `22_up_conduit.sh -s emulated_asis -d` で config 生成のみを行い、生成 `.conf` の `application [ ... ];` を確認。
4. netoviz 上で FW ノード属性表示が壊れていないか確認 (配列表示の可否は未調査。netoviz 側に application を参照するコードは grep では見つからなかった)。

## リスク・未確認事項

- netomox gem が配列を受け付けるか (Step 0)。
- TTP のグループ指定でマルチライン `[` ... `]` を安全に取れるか (実験が必要)。
- 既存の保存済み topology JSON (`application` が String のもの) との後方互換。
- `configs/mddo-fw` の現在の未コミット変更との衝突。
- `demo/copy_to_emulated_env/` など他の生成経路があるか (grep 範囲では vsrx_cluster.j2 のみ)。

## 承認依頼事項

(1〜3 は回答済み。上記「決定事項」参照。残るは実装開始の承認のみ。)

## レビュー対応 (code-reviewer)

- M-1 (netomox の default 共有): `.dup` で解消、回帰 spec 追加。
- M-2 (`inactive: policy` の合流): `_remove_inactive_policies` で除外、テスト追加。`global { policy }` / ブロック形式 action / 行末コメントは既知の制約として design-notes に記載。
- L-2 (空リスト): `controller.yaml` に検証タスク (assert) を追加。空の match 条件があれば vsrx config 生成前に停止。
- L-5: docs の版表記 (parser v0.2.0 / netomox 0.15)、`reject`、F-3 の状態を更新。
- M-3 (リリース順序): netomox 0.15.0 公開 → netomox-exp / model-conductor の Gemfile.lock 更新 → parser を公開、の順。
- 未対応: `junos_list` の描画 test (demo 側にテスト基盤が無いため、手動確認のみ)。
