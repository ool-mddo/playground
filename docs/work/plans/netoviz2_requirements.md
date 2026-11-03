# netoviz2 要求・設計・実装計画

> 状態: 実装中 (2026-11-02 時点)。段階 1〜3・5 は実施済み (進捗は 8 を参照)。段階 4 (dependency 表示) とレイアウトエンジンの検証 (7.8.1) は未着手。
> 構成: 1 背景 → 2 目的・基本方針 → 3 要求 → 4 決定事項 → 5 現状調査 → 6 妥当性評価 → 7 設計 → 8 実装計画 → 9 リスク・未確認事項 → 付録

---

# 1. 背景・経緯

* netoviz は当初、これ単独で独立したソフトウェアとして設計・実装したツールであり、mddo-pj での使い方はあとから応用したもの。そのため、データの処理・加工 (RFC8345 トポロジの読み込み、図ごとの view model への変換、index・属性の読み取りなど) を netoviz 自身のサーバサイドが受け持っている。
* mddo-pj ではトポロジデータの保存・変換・提供は本来バックエンド (netomox-exp) の責務であり、**データ加工の責務が netoviz と netomox-exp に分かれて置かれている。**
* その結果、他ツールと揃わない次の構造が生じている。
  * サーバ側コードをクライアントが直接 import する密結合 (`server/graph` ↔ `lib/diagram`)
  * トポロジファイルを共有 volume (bind mount) 経由で受け渡す結合
  * nginx を経由せず、直接アクセスする独自の URL 体系
* (調査上、同等処理の重複そのものは `_index.json` 読み取りと networks-attributes のキー知識に限られる。問題の本質は機能の重複ではなく、**責務の置き場所**と、フロント/バックエンド間の**データ契約が暗黙であること**にある。)

# 2. 目的・基本方針

* **データ加工をバックエンド (netomox-exp) へ寄せ、フロントエンド (netoviz2) は描画と操作に専念する。** これが基本方針。
* 機能・実装の無駄を排除し、mddo-pj の用途に向けてシンプルかつ軽量にする。
* netoviz の考え方を土台にするが、データフォーマットは新たに設計する。

# 3. 要求

## 3.1 機能
* 複数レイヤのトポロジを持つ RFC8345-based topology JSON を読んで表示する。
* 含まれるレイヤ単位でトポロジを表示・確認できる。
* レイヤ間のオブジェクト (node, term-point, link) がもつ依存関係 (support) をトレースできる。
* オブジェクトを選択したとき、その attribute を表示できる。
  * マウスオーバーの pop-up は attribute が増えると表示が難しいので、視認性に優れた表示方法にする。
* オブジェクト選択・support トレース・attribute 表示は **Viewer によらず共通の処理**として実装する。
* NW 全体のメタデータ (networks flags) を表示できる。
* diff 表示 (追加/削除/変更) を維持する。
* 自動リロード (トポロジ更新の検知と再描画) を維持する。
* alert ハイライトは廃止する。

## 3.2 Viewer
* force-simulation: 原則維持 (最も使用頻度が高い)。
* dependency: そのまま維持する必要はない。レイヤ間の階層分けについてより良い表示があれば新設計する。
* nested / distance: 一旦保留 (実装しない。nested の layout 保存も不要)。

## 3.3 アクセス経路・構成
* api-proxy (nginx) 経由でアクセスする: `http://localhost:15000/netoviz2/:nw/:ss/`。
* netoviz2 はローカルディレクトリへの bind mount を持たない。トポロジファイルのアクセス・データ処理は netomox-exp に寄せ、netoviz2 は REST API 経由の通信のみとする。できればバックエンドは netomox-exp のみに依存させる。
* API は既存 (netoviz の `/api/...`) を維持せず、他ツールの体系に合わせる。

## 3.4 データ
* **netoviz2 は refocus_topology 専用ではなく、他のユースケースでも使う汎用トポロジビューワーとして位置づける。** mddo-fw 以外のトポロジデータ (mddo-bgp, mddo-mregnw, mddo-ospf など) を踏まえて仕様を検討する。フロントはユースケース名・レイヤの種類・属性スキーマに依存する分岐を持たず、未知のものは汎用の表示にフォールバックする。
* link の support / attribute は現状実利用が無く優先度を下げてよい。ただしデータ仕様上は持たせられるため、後から入れられる枠組みは用意する。
* 想定規模: 100 ノード程度、1 デバイスあたり数十〜100 term-points。

## 3.5 実装条件
* netoviz2: Node.js + TypeScript ベース。フレームワークは原則 netoviz と同様だが、より良い方法があれば変えてよい。UI ライブラリは軽量なものに変えてよい。
  * `playground/repos/netoviz2` で構築し、コンテナイメージを作成する。実装・動作確認後に playground のサブモジュールとして登録する (それまでは独立リポジトリ)。
* netomox-exp: main HEAD (v1.20.0) から作業ブランチを作る。既存機能への影響を避けるため、netoviz2 向けのデータ処理は別モジュールに分割する。

# 4. 決定事項

| 項目 | 決定 |
|---|---|
| 責務分離 | データ加工 = netomox-exp、描画・操作 = netoviz2 |
| 案の選択 | 案B (新規 netoviz2 SPA + netomox-exp が整形済みモデルを返す) |
| フロント構成 | Vite + Vue 3 + TypeScript の SPA、静的配信 (理由は 7.6) |
| UI | 軽量方針 (Vuetify 不採用)。必要部品は自作、headless 系ライブラリ利用可 |
| フロント URL | `/netoviz2/` (一覧)、`/netoviz2/:nw/:ss/` (表示) |
| API | netomox-exp に追加。`/topologies/:nw/:ss/netoviz2/...` (汎用名 `view` は避ける) |
| diff 判定 | snapshot 名ではなく、各オブジェクトの `_diff_state_` を見て処理を切り替える。ただし `_diff_state_` は非 diff のトポロジにも (`kept` で) 入っているため、存在ではなく導出した状態 (`added` / `deleted` / `changed`) で判定する |
| 引き継ぎ機能 | diff / networks flags / 自動リロード = 継続、alert = 廃止 |
| link の support/attribute | スキーマ上の枠のみ用意、実装は後回し |
| 開発時運用 | Vite dev server から api-proxy へプロキシ |
| 並行稼働 | 現行 netoviz は netoviz2 が必要機能を満たすまで置き換えない |
| レイアウトエンジン | **force (d3-force) と自前の stress の 2 つ。既定は stress。ELK は採用しない** (品質で自前の stress に及ばず、EPL-2.0 の対応と約 1.5MB が必要なため)。設計と経緯は [design_notes/netoviz2_layout.md](../../design_notes/netoviz2_layout.md) |
| gem の利用 | netomox-exp の整形処理は netomox gem のオブジェクトモデルを使う (整合性・保守性・可読性を優先)。性能は厳密に求めず、問題があれば gem 側を改善する。gem が保持しない属性が必要なら gem 側に追加する |
| 位置づけ | ユースケース非依存の汎用トポロジビューワー。ユースケース・レイヤ種別・属性スキーマ固有の知識をフロント/バックエンドの共通処理に持たせない (固有の見せ方は属性キーをキーとするオプション拡張) |
| レイヤ間の依存 | `supporting-network` の宣言ではなく、宣言と実際の node/tp support の和集合から求める (実データで両者が一致しない) |

**残る確認事項: なし** (8 の実装計画 1 へ進める状態)。

---

# 5. 現状調査 (netoviz / netomox-exp)

調査は読み取りのみで、テストは未実行。

## 5.1 netoviz (v0.10.1)
* Nuxt 4 / Vue 3 / Vuetify 4 / Pinia / D3。サーバは Nitro に Express Router をマウント (`server/plugins/express-api.js`)。
* 規模: server/ 約 8,900 行、lib/ 約 6,500 行、components/ 約 1,200 行。Viewer は forceSimulation / dependency / dependency2 / nested / distance の 5 種。
* サーバの仕事: 「RFC8345 JSON → 図ごとの view model JSON」変換 (`server/graph/*`)、`_index.json` 読み取り、networks-attributes 読み取り、status (mtime) 返却、nested の `layout.json` 書き込み。
* **サーバ側コードをクライアントが直接 import している。** 例: `lib/diagram/common/tooltip-creator.js` が `server/graph/rfc-model/*-attr/*.js` の属性クラス (`toHtml()`) を呼ぶ。`alert-util.js` は Nuxt の制約でサーバ/クライアントに複製されている。
* support の辿り方は Viewer ごとに別実装。force-simulation ではサーバが parents/children を付与し、クライアントがクリック時に再帰でハイライトする (循環ガードなし)。サーバの family-maker とクライアントの家系計算も別実装。
* 属性表示は tooltip。属性ごとの HTML 生成クラス (`AttributeClassOf` の辞書) で、属性追加のたびにクラスと辞書の追加が必要。
* diff: トポロジ JSON の各オブジェクトに入った `_diff_state_` (`forward` / `backward` / `pair` / `diff_data`) を読んで色分け・属性差分表示する (`server/graph/rfc-model/base.js`, `common/diff-state.js`)。
* 他システムは netoviz の HTTP API を呼んでいない。結合点は (a) 共有 named volume `topologies` (netomox-exp が書き netoviz が読む)、(b) netomox-exp の `/topologies/index` 経由の `_index.json` 更新、のみ。

## 5.2 netomox-exp
* **Grape** (Ruby 3.4)。`app.rb` が `/topologies` と `/usecases` を mount。業務ロジックは `lib/<domain>/`、API は `lib/api/` で `ApiRoute::*` を mount する流儀。テストは RSpec + rack-test (`spec/support/api_helper.rb` に fixture ヘルパーあり)。
* トポロジ Read は既にある (`GET /topologies/:nw/:ss/topology`、`/topology/:layer`、`/:layer/nodes|interfaces` 等)。保存は `$MDDO_TOPOLOGIES_DIR/<nw>/<ss>/topology.json`。
* **netoviz 向けの専用処理は `_index.json` の読み書きのみ。** 図用変換・layout は無い。
* 配置上の制約: nginx (api-proxy) は `/topologies/` と `/usecases/` のみ netomox-exp へ転送。bind mount は `lib/`・`app.rb`・`config.ru` のみ (`lib/` 外の新規ディレクトリはライブ反映されない)。

# 6. 妥当性の評価

結論: **netoviz2 を新しく作ること自体は妥当。** 動機は「重複排除」ではなく「責務分離」として整理する (1・2 に反映済み)。

## 6.1 妥当と判断できる点
1. **データ契約が暗黙で、サーバ/クライアントが密結合。** 変換ロジックの変更が描画に波及する。HTTP + 明示スキーマで分離する価値は大きい。
2. **機能過多。** 5 Viewer と各専用の view model・属性クラスで約 1.6 万行。force-simulation + 新 dependency に絞れば大幅に小さくできる。
3. **属性表示のスケーラビリティ問題は実在する。** 属性クラスごとの HTML 生成は tooltip に収まらない。
4. **support 追跡の共通化は筋がよい。** 現状 Viewer ごとに別実装で、循環ガードも無い。

## 6.2 注意点
* 図用 view model 変換は netomox-exp に同等処理が無い。バックエンド寄せは **Ruby での新規実装** (移植ではなく新スキーマでの実装) になり、工数が出る。
* 「作り直し」は機能欠落・回帰が起きやすい。現行 netoviz と並行稼働し、機能比較を経て置き換える。

## 6.3 代替案の比較

| 案 | 内容 | メリット | デメリット |
|---|---|---|---|
| A. netoviz を in-place で縮小改修 | nested/distance 削除、サーバを薄く | 資産を流用、移行リスク小 | データ契約・SSR 前提・属性クラス結合が残る。フォーマット再設計の要求に反する |
| **B. 新規 netoviz2 (SPA) + netomox-exp が整形済みモデルを返す (採用)** | バックエンドで正規化・support 解決、フロントは描画のみ | 責務が明快、フロントが軽量、スキーマを docs に固定できる | netomox-exp に新規実装が必要、現行機能の再実装 |
| C. 新規 netoviz2 が生の RFC8345 を直接パース | netomox-exp 変更が最小 | バックエンド実装が少ない | 「データ加工はバックエンド」の要求と逆。フロントが再び重くなる |

---

# 7. 設計

## 7.1 全体構成

```
ブラウザ ── http://localhost:15000 ──> api-proxy (nginx)
                                        ├─ /netoviz2/   -> netoviz2 コンテナ (nginx + 静的 SPA、volume なし)
                                        ├─ /topologies/ -> netomox-exp (REST、トポロジ Read/加工)
                                        └─ (他ツール)
netomox-exp ── topologies volume (読み書き)   ※ netoviz2 は volume を持たない
```
netoviz2 の依存先は netomox-exp (api-proxy 経由) のみ。

## 7.2 責務境界
判断基準: **データの意味に関わる処理はバックエンド、見た目と操作に関わる処理はフロント。**

| バックエンド (netomox-exp) | フロント (netoviz2) |
|---|---|
| RFC8345 の正規化 (フラット化、安定 ID 付与) | レイアウト (d3-force、レイヤ帯配置) |
| レイヤ一覧と、レイヤ間の依存順序の算出 | 選択状態管理、ハイライト |
| support の解決 (node / tp / link、双方向索引)、整合性検証 (参照欠落・循環) | support トレースの表示 (取得済み索引を辿る) |
| 属性の取り出し (gem が保持する属性を整形せず返す。`mddo-topology:*` を含む) | 属性パネルの描画 (汎用ツリー) |
| networks-attributes (flag)、diff 状態の提供 | 表示フィルタ・検索、diff 色分け |
| index・変更検知 (ETag) | ポーリング・再描画 |

* support トレース自体は、モデル取得済みの索引をクライアントで辿る (応答速度のため)。循環ガードは共通実装 1 か所に置く。
* **整形処理は netomox gem のオブジェクトモデルを使って実装する** (決定)。データの整合性・一貫性を gem に任せ、保守性と可読性を優先する。生の Hash を直接操作しない。性能は厳密には求めず、遅い場合は netomox-exp 側で回避せず gem 側を改善する。
  * 制約: gem は `ATTR_DEFS` に宣言されたキーしか保持しない (調査: netomox 0.15.0 のローカル checkout)。そのため `attributes` は「gem が保持する属性」に限られ、node 直下の `flag` などは現状表示されない。必要なら gem 側に属性を追加する。段階 2 の最初に 53 ファイルの往復で失われるキーを数えて一覧化する (詳細は `docs/netoviz2_data_format.md` の 11)。

## 7.3 データモデル (叩き台)
ネストせず、フラット配列 + 参照 ID にする。**正式な仕様は [docs/netoviz2_data_format.md](../../netoviz2_data_format.md)** (本節の JSON は概念図)。
実データでは node-id / tp-id に `/` が含まれる (例: `Seg_172.32.0.0/30`、`ge-0/0/0.0`) ため、下の例のような単純な `/` 連結の ID は曖昧になる。仕様では各セグメントをエンコードして連結する方式にした。

```json
{
  "schema_version": "1",
  "network": "mddo-fw", "snapshot": "original_asis",
  "flags": ["blueprint=..."],
  "layers": [
    {"id": "layer3", "kind": "mddo-l3", "supports": ["layer2"], "counts": {"nodes": 8, "tps": 30, "links": 12}}
  ],
  "nodes": [{"id": "layer3/r1", "layer": "layer3", "name": "r1", "diff": "changed"}],
  "tps":   [{"id": "layer3/r1/ge-0/0/0", "node": "layer3/r1", "name": "ge-0/0/0"}],
  "links": [{"id": "layer3/r1,ge-0/0/0,r2,ge-0/0/1", "layer": "layer3", "src": "layer3/r1/ge-0/0/0", "dst": "layer3/r2/ge-0/0/1"}],
  "supports": [{"kind": "node|tp|link", "from": "layer3/r1", "to": "layer2/r1"}]
}
```
(上は構造部分。`attributes` / `diff_data` は後述のとおり別 API で遅延取得する。)

* **構造と属性の分離:** 構造 = ID・親子・接続・support・diff 状態。属性 = `attributes` / `diff_data`。想定規模では TP が 1 レイヤで最大約 1 万、全レイヤ合計で数万オブジェクトになりうるため、属性は選択時に ID 指定で取得する。
* `attributes` は gem が保持する属性 (mddo 拡張を含む) を整形せずそのまま返す。フロントは属性クラスを持たない。
* **diff:** 各オブジェクトの `_diff_state_` から状態を導出し、`added` / `deleted` / `changed` の場合のみ `diff` を付与する (`kept` と `_diff_state_` なしはキー無し)。`summary` の `has_diff` は導出した状態が `kept` 以外のものがあるかで決め、フロントは diff UI (凡例・フィルタ) の出し分けに使う。snapshot 単位の diff 設定は持たない。
  * **実データでの確認:** `_diff_state_` は diff でないトポロジにも入っている (netomox gem の `to_data` が常に出力する。`topologies/mddo-bgp/original_asis` は 1,372 個のオブジェクトが `forward=kept`、diff なし)。そのため「`_diff_state_` の存在そのもの」を diff 判定にすると常に真になる。判定は存在ではなく導出した状態で行う。
* **link の枠組み:** スキーマ上 `supports[].kind` に `link`、link の `attributes` を最初から許容する。バックエンドの support 解決はノード/TP 用ビルダーと同じインタフェースに `link` 用ビルダーを後から差し込める構造にする (初期は未実装 = 空)。フロントのトレース処理は kind に依存しない実装にする。
* canonical definition は `docs/netoviz2_data_format.md` (他の属性スキーマ文書と同様に playground の docs に置く) に別途作成し、`schema_version` で互換性を管理する。

## 7.4 API (netomox-exp)
`/topologies/:nw/:ss/` 配下に置く (api-proxy で既に転送されるので nginx 変更不要)。リソース名は netoviz2 専用と分かる `netoviz2`。

| API | 内容 |
|---|---|
| `GET /topologies/:nw/:ss/netoviz2/summary` | レイヤ一覧 (id・kind・支持関係・件数)、`flags` (networks-attributes)、`has_diff`、`etag` |
| `GET /topologies/:nw/:ss/netoviz2/layers/:layer` | 当該レイヤの構造 (nodes / tps / links。属性なし) |
| `GET /topologies/:nw/:ss/netoviz2/supports` | レイヤ間 support (全体) |
| `GET /topologies/:nw/:ss/netoviz2/attributes?ids=a,b,c` (または POST) | 指定 ID の `attributes` / `diff_data` |
| `GET /topologies/index` (既存) | network / snapshot 一覧 |

* **自動リロード:** `summary` の `etag` を `If-None-Match` 付きでポーリング (304 で軽量)。etag はファイルの mtime+size から作る。接続保持が不要で nginx のタイムアウトに影響しない。SSE は必要になってから検討。
* **キャッシュ:** 正規化結果は mtime をキーにプロセス内にキャッシュする。
* **gzip:** 現行 `assets/api-proxy/default.conf` には無い。`/topologies/` 向けに `gzip on; gzip_types application/json` を追加する (7.9 の計測結果で要否を最終判断)。

## 7.5 netomox-exp の実装方針
* main HEAD (v1.20.0) から作業ブランチを作る。
* ロジック: `lib/netoviz2/` (新規。`lib/` 内なのでライブ反映される。名前空間も netoviz2 に閉じる)。
* API: `lib/api/topologies/network/snapshot/netoviz2.rb` を `snapshot.rb` から mount。既存ファイルの変更は mount 1 行に留める。`/topology/:layer` とは別の兄弟リソースにして衝突を避ける。
* テスト: `spec/netoviz2/` と `spec/api/` に追加し、既存 fixture ヘルパー (`spec/support/api_helper.rb`) を再利用する。参照欠落・循環・`_diff_state_` を持つ/持たないオブジェクトの混在をカバーする。

## 7.6 netoviz2 の実装方針

### 技術選定
* **Vite + Vue 3 + TypeScript の SPA、ランタイムの Node サーバ無し。** 「node.js ベース」は開発・ビルド環境として満たす。
* 状態管理は Pinia、UI は軽量方針 (自前 + 最小限の CSS、必要なら headless 系)。

**Vite SPA を選ぶ理由**
1. netoviz2 のサーバ機能 (ファイル読み書き・変換) が無くなり、Nuxt の主な価値 (SSR、server routes/Nitro) を使わない。
2. 静的ファイルのみの配信になり、コンテナは nginx + 静的成果物で済む (Node ランタイム・node_modules 不要、イメージが小さく、実行時の更新対象も減る)。
3. サブパス配信 (`/netoviz2/`) は Vite の `base` と nginx の `try_files` で素直に実現できる。
4. 内部ツールで SEO・初期表示 SSR の必要が無い。

デメリットは `vue-router` 等を自前設定する手間のみ (ページ数が少なく影響小。同じ Vue 3 なので学習コストも小さい)。中間案として Nuxt の SPA モード (`ssr: false` + `nuxt generate`) でも静的配信にできるが、Nuxt 本体と周辺モジュールの追従コストは残る。

### アクセス経路
* `/netoviz2/` = network/snapshot 一覧 (`/topologies/index` から)、`/netoviz2/:nw/:ss/` = 表示。Viewer・レイヤ・選択はクエリパラメータ (例: `?viewer=force&layer=layer3&sel=<id>`) に載せ、リンクで状態共有できるようにする。
* `assets/api-proxy/default.conf` に `location /netoviz2/ { proxy_pass http://netoviz2:80; }` を追加 (このファイルは現在 git 上で変更済み (`M`) なので、編集前に差分を確認する)。netoviz2 コンテナは nginx + 静的成果物 (`try_files $uri /netoviz2/index.html`)、Vite の `base: '/netoviz2/'`。
* API 呼び出しは同一オリジンの相対パス (`/topologies/...`) なので CORS 不要。ホスト名・ポートのハードコードも不要。

### bind mount なし
* netoviz2 コンテナは `topologies` volume を含むいかなる volume も持たない。
* 開発時の live reload は Vite dev server (`npm run dev`、`/topologies` を api-proxy へプロキシ) で行い、本番コンテナは静的成果物のみ。

## 7.7 共通部品と Viewer

### Viewer 非依存の共通部品
* `selection` ストア: 選択オブジェクト、トレース結果 (上位/下位レイヤの support 先)。
* `SupportTracer`: 索引を辿る純関数 (循環ガード付き、ユニットテスト対象)。
* **属性パネル:** tooltip を廃止し、右サイドパネルに固定表示 (選択で更新)。汎用 JSON ツリー、キー検索・折りたたみ、必要に応じてピン留め。diff があれば差分を強調。mddo 固有の見せ方 (fhrp、FW 属性など) は、汎用ツリー上の薄い拡張として後から追加。
* networks flags 表示、etag ポーリング (自動リロード)、diff 凡例/フィルタ。

### Viewer
* **force-simulation:** 維持。レイヤ単位の表示切替・フィルタを追加。
* **dependency:** レイヤ帯 (swimlane) 型の階層表示を新設計案とする。レイヤを上下の帯とし、帯内にノードを置き、support を帯間の線で描く。レイヤ依存の DAG 順に並べ、選択でトレース経路を強調。
* nested / distance: 保留。

## 7.8 force-simulation の描画方式
「force-simulation の維持」は D3.js の利用を必須とするものではない。d3-force は物理計算のみで、描画 (SVG / Canvas / WebGL)・ヒットテスト・ズーム・ドラッグは別に選べる (現行 netoviz は d3-force + d3-selection で描画まで自前実装)。

| 選択肢 | 向いている点 | 懸念 |
|---|---|---|
| d3-force + 自前描画 (**第一候補**) | 依存が最小。現行の知見を流用でき、選択・トレース・diff 色分けを自由に作れる | Canvas にするとヒットテスト・ズーム・ドラッグを自作する必要がある |
| Cytoscape.js | node ⊃ TP を表す入れ子ノード (compound) が標準。選択・スタイル・イベント・レイアウト拡張が揃う。数千要素規模の実績あり | 本体が数百 KB で軽量化方針とはやや反する。細かい作り込みはライブラリの流儀に縛られる |
| Sigma.js + graphology (WebGL) | 1 万〜10 万ノード規模でも軽い | 入れ子ノードが無く、TP を親ノード内に表示しにくい。ラベル・属性の見せ方の制約が大きい |
| force-graph (vasturiano) | d3-force + Canvas の薄いラッパー。API が簡単 | 入れ子・階層表現は自作。カスタマイズ余地は限定的 |
| vis-network | 導入が最も簡単 | 大規模時の性能と細かい制御が弱い |

* dependency の配置には `elkjs` / `dagre` などの階層レイアウトライブラリも選べる。帯が数枚で配置が単純なら自前計算でも足りる。Vue Flow は DOM 描画のノードエディタ向けで対象外。
* **方針:** まず d3-force + SVG (ノード単位表示 + TP 展開、7.9) で始める。共通部品は描画ライブラリに依存させず、Viewer の描画部分だけを差し替え可能な構造にする。
* **判断基準:** 合成フィクスチャで計測し、SVG で重い場合の次の候補を次の順で検討する: (1) Cytoscape.js (入れ子ノードが標準)、(2) d3-force + Canvas 自作 (依存を増やしたくない場合)、(3) Sigma.js (一度に表示する要素が 1 万を大きく超える場合に限る)。
* 評価項目: 描画の滑らかさ (FPS)、TP 展開時の応答、入れ子表現のしやすさ、バンドルサイズ、diff 色分け・トレース強調の実装量。

## 7.8.1 レイアウトエンジンの選択肢 (案。手動確認のフィードバックを受けて追記)
ネットワーク構成図向けの専用レイアウトエンジンは無いため force-simulation を使っているが、リンク・ノードの重なりをより減らす方法として次がある。

| 案 | 内容 | 利点 | 懸念 |
|---|---|---|---|
| A. force + 改善 (**実施済み**) | ウォームアップ、複数回の初期化から「リンクの交差数 + ノードの重なり」が最小のものを採用、TP をノードの円周上のポートとして配置 (相手ノードの方向に向ける。物理計算の対象外) | 追加の依存なし。現行の見た目と操作を維持。実データ最大 (315 ノード + 720 TP) でも 0.6 秒以内 | 交差ゼロは保証できない (メッシュ状のトポロジでは限界がある) |
| B. ELK (elkjs) | layered (階層)・stress・force・radial などのアルゴリズム。**ポート (ノードの辺上の接続点) と直交配線を標準でサポート**、ノードの重なり除去あり | 構成図らしい配置 (コア/集約/アクセスのような階層) と、ポート単位の配線ができる。交差の最小化を行う | バンドルが大きい (約 1.5MB。遅延読み込みで緩和)。メッシュ状では階層にしづらい。ポートの角度制御は layered / force で挙動が異なる。実データで評価が必要 |
| C. Graphviz (WASM) | dot (階層)・neato/sfdp (stress + 重なり除去) | 成熟したアルゴリズム、重なり除去が強い | WASM が大きい (約 1.5MB)。ポート制御は限定的。対話的な更新 (展開・折りたたみ) に不向き |
| D. WebCola / Cytoscape の cola・fcose | 制約付き force (重なり回避、整列、flow の方向制約) | 現行の force に近い操作感のまま、重なりと配置の制約を足せる | fcose は Cytoscape が必要 (描画ライブラリの変更を伴う)。WebCola は更新が少ない |
| E. 自前の階層化 (hop 距離) | 基準ノード (ユーザーが選択 or 次数最大) からのホップ数で段に分け、段内は隣接ノードの重心順 + force で調整 | 実装が小さく、依存なし。ハブ&スポーク型で効く | 汎用性は限定的。交差最小化は簡易 |
| F. 手動調整 + 保存 | 自動配置を初期値にし、ノードを手で動かして位置を保存 (バックエンドに保存する API が必要) | 構成図として最も確実。他の案と併用できる | netomox-exp に保存用の書き込み API が必要 (既存の netoviz の `layout.json` に相当) |

**推奨:** A を既定のまま、**B (ELK) を試験導入する検証 (spike)** を行う。レイアウト計算を描画から切り離し (入力: ノード・リンク・ポート、出力: 位置)、エンジンを切り替えられる構造にする。mddo-fw / mddo-mregnw で A と B を比較する (交差数、重なり、所要時間、バンドルサイズ、見た目)。F (手動調整の保存) は別途、必要性と保存先 (バックエンドの API) を決める。
**実施済みの改善 (A):** 詳細は 8 の進捗を参照。

### 7.8.2 検証結果: force (A) と ELK (B) の比較 (実データ)
netoviz2 に両方のエンジンを実装し、`?layout=<engine>` で切り替え、「Compare layouts」(`?compare=<engine>`) で左右に並べて比較できる。各パネルが所要時間・リンクの交差数 (ELK layered は折れ点の経路で数える)・ノードの重なりを表示する。ELK は layered / stress / force の 3 つ (ELK の force は d3 の force とは別のアルゴリズム)。条件はノード単位表示 (TP は円周上のポート。レイアウトの対象外) のレイアウト。

| データ (ノード, リンク) | force (d3、複数回の初期化) | ELK layered | ELK stress | ELK force |
|---|---|---|---|---|
| mddo-fw layer3 (54, 66) | 520 ms / 交差 24 | 403 ms / **110** | 635 ms / **12** | 654 ms / 162 |
| mddo-mregnw layer1 (40, 55) | 557 ms / 9 | 122 ms / **5** | 337 ms / 10 | 320 ms / 46 |
| mddo-mregnw layer3 (85, 110) | 736 ms / 29 | 356 ms / 285 | 1232 ms / **15** | 1184 ms / 329 |
| mddo-mregnw layer2 (140, 85) | 1270 ms / 4 | 157 ms / **0** | 221 ms / **0** | 199 ms / **0** |
| mddo-bgp layer3 (53, 54) | 545 ms / 10 | 242 ms / 62 | 540 ms / **0** | 496 ms / 106 |
| mddo-fw 全 7 レイヤ (222, 213) | 2190 ms / 54 | 299 ms / 181 | 966 ms / **22** | 913 ms / 349 |

(ノードの重なりは全エンジン・全データで 0。ヘッドレス Chrome での測定で、初回の ELK の読み込み時間は含まない。)

**所見**
* **ELK stress が総合的に最良**: 交差数は force (d3) 以下 (mddo-fw layer3 で 12 vs 24、mregnw layer3 で 15 vs 29、全 7 レイヤで 22 vs 54)。時間は同程度で、大きなグラフ (140・222 ノード) では force より速い。ただし配置が広がり、同じ表示領域では縮小される。mddo-mregnw layer1 では force の方が交差が少なかった (9 vs 10)。
* **ELK layered は階層的なトポロジで有効、メッシュ状では不向き**: 疎な階層構造 (mregnw layer1・layer2) では交差が最小かゼロで、上から下への流れが明確になる。一方、L3 のように密なメッシュ (セグメントノードが多数の機器をつなぐ) では交差が大幅に増える (110・285)。
* **ELK force は他に劣る** (交差が多い)。選択肢から外してよい。
* **d3-force (複数回の初期化)** は、領域をコンパクトに使う。小さなグラフでは交差を減らせるが、ELK stress には及ばない。実装済みの改善 (交差が 0 になるまで再試行) で、小さなグラフの「ねじれ」は抑えられた (4 ノードのリングでは 1 回の初期化では 58% が交差、再試行後は 0)。
* ELK は大きい (約 1.5MB、gzip で約 450KB)。使うときに初めて読み込むため、他のエンジンには影響しない。
* **ライセンス: elkjs は EPL-2.0 OR GPL-3.0-or-later。本プロジェクトは MIT。** 依存として使い、改変せずに配布する範囲で問題になるかを、本採用の前に確認する必要がある。

**推奨 (案)**: 既定のエンジンを ELK stress にする (または force と stress をユーザーが選べるようにしたまま、既定を stress にする)。階層的なトポロジ向けに ELK layered を選択肢として残す。ELK の force は外す。ライセンスの確認が済むまでは、既定を force のままにしておくこともできる。
> **決定 (7.8.1〜7.8.3 の検討を受けて)**: エンジンは force (d3-force) と自前の stress の 2 つとし、既定を stress にする。**ELK は採用しない。** 設計の詳細・検討した選択肢・比較結果・ELK のライセンス分析は [design_notes/netoviz2_layout.md](../../design_notes/netoviz2_layout.md) に移した (以下の 7.8.1〜7.8.3 は、検討の過程の記録)。ELK の検証用に入れていたコード・依存・経路 (折れ点) の描画は削除した。

### 7.8.3 自前のストレス最小化 (stress (own)) と ELK stress の比較
ELK stress の元は標準的な手法 (ストレス最小化。Gansner ら 2004) なので、同じ手法を自前で実装し (依存なし。`src/render/layout/stress.ts`)、エンジン `stress` として追加した。リンクの長さを「間隔 + 両端ノードの半径」にしてノードの大きさを考慮し (TP を展開した大きなノードが離れる)、連結成分ごとに別々に配置して (複数回の初期化から交差・重なりが最小のものを採用、交差ゼロで打ち切り)、最後に重なりを除去し、成分をグリッドに並べる。URL は `?layout=stress`、「Compare layouts」では `stress` と ELK stress を比較する (他のエンジンは `stress` と比較する)。

| データ (ノード, リンク) | force (d3) | **stress (own)** | ELK stress | ELK layered |
|---|---|---|---|---|
| mddo-fw layer3 (54, 66) | 529 ms / 21 | **267 ms / 6** | 885 ms / 12 | 280 ms / 110 |
| mddo-mregnw layer1 (40, 55) | 526 ms / 11 | **128 ms / 5** | 453 ms / 10 | 128 ms / 5 |
| mddo-mregnw layer3 (85, 110) | 790 ms / 41 | **434 ms / 10** | 1326 ms / 15 | 225 ms / 285 |
| mddo-mregnw layer2 (140, 85) | 1264 ms / 1 | **22 ms / 0** | 322 ms / 0 | 161 ms / 0 |
| mddo-bgp layer3 (53, 54) | 535 ms / 7 | **49 ms / 0** | 540 ms / 0 | 134 ms / 62 |
| mddo-fw 全 7 レイヤ (222, 213) | 2244 ms / 69 | **344 ms / 14** | 978 ms / 22 | 317 ms / 181 |
| mddo-mregnw 全 5 レイヤ (315, 300) | 3605 ms / 78 | **602 ms / 15** | 1818 ms / 25 | 469 ms / 305 |

(各セルは「所要時間 / リンクの交差数」。ノードの重なりは全エンジン・全データで 0。ヘッドレス Chrome での測定。)

* **自前の stress は、全データで ELK stress と同等以上** (交差数: 7 データ中 5 で少なく、2 で同じ。所要時間は 2〜10 倍短い)。ELK のようなサイズ (約 1.5MB) の読み込みも要らない。
* 配置はより**コンパクト** (既定の間隔が ELK の既定 (140) より短い。パラメータで変えられる)。
* 実装は約 250 行 (最短経路のヒープ、ストレス最小化、重なり除去、成分の配置) とテスト 10 例。保守は自分たちで行う。
* ELK stress を外しても品質は落ちないが、**ELK layered (階層) は自前では代替がない**。階層表示が必要な場合は、ELK layered を残す (その場合のライセンス対応は、本節の前の判断材料を参照) か、dependency 表示 (段階 4) で別途実現する。

残る課題: TP のポートも考慮したレイアウト (ELK のポート制約) の評価、ELK の Web Worker 化 (大きなグラフで画面が固まらないように)、手動調整の保存 (7.8.1 の F)。

## 7.9 規模対策 (100 ノード × 数十〜100 TP)
* 見積り: 1 レイヤで TP 最大約 1 万、リンクも同程度。全レイヤ合計で数万オブジェクト。現行の SVG 全要素描画では重くなる懸念が大きい。
* **データ転送:** レイヤ単位取得 + 構造/属性の分離 (7.3, 7.4)。属性は選択時に遅延取得。gzip を併用。
* **force-simulation の描画:**
  * 既定は **ノード単位表示** (ノード間リンクは TP 間リンクを束ねて本数を表示)。ノードの選択/ダブルクリックで該当ノードの TP を展開 (LOD)。
  * TP 展開時のノード数を制限し、非表示部分はシミュレーション対象から外す。
  * まず SVG + LOD で測定し、必要なら Canvas 等へ切り替える (7.8)。
* **dependency (レイヤ帯) の描画:** 全 TP を並べると破綻するため、既定はノード単位。選択ノードのトレース先のみ TP まで展開する。
* **検証 (最初に実施):** 100 ノード × 100 TP の合成フィクスチャ生成スクリプト (netomox-exp 側テスト用) を作り、(a) Ruby 側の正規化時間、(b) 応答サイズ (gzip 前後)、(c) 描画 FPS を測定してから方式を確定する。

---

# 8. 実装計画

各段階の完了ごとに確認を取り、承認を得てから次へ進む。

| # | 段階 | 内容 | 完了条件 |
|---|---|---|---|
| 1 | 仕様確定 (コード無し) | `docs/netoviz2_data_format.md` と API 仕様を作成してレビュー。netomox gem の流用可否を確認 | 仕様文書の承認 **(ドラフト作成済み。レビュー待ち。gem を使う方針で決定)** |
| 2 | netomox-exp | main HEAD から作業ブランチ。**実データ (mddo-fw / mddo-mregnw / mddo-ospf emulated_tobe (参照切れあり) / ietf 最小構成 / diff 入りなど、リポジトリ内で公開されているもの) を回帰テストの fixture にし** (非公開データはリポジトリの fixture やドキュメントに含めない)、さらに合成フィクスチャ (100 ノード × 100 TP) と計測スクリプトを作る。**最初に gem の往復確認 (53 ファイルを読み込み → `to_data` で、失われるキーを一覧化して gem 側の修正候補にする。コンテナ内の gem の版も確認)** → `lib/netoviz2/` に gem を使った正規化 + support の解決 + diff 状態の導出を実装 → `netoviz2/*` API (summary / layers / supports / attributes、etag) を mount | RSpec 通過、規模計測の結果報告 |
| 3 | netoviz2 MVP | リポジトリ雛形 (Vite + Vue 3 + TS)、一覧ページ、レイヤ取得、force-simulation (ノード単位 + TP 展開)、選択 + 属性パネル + support トレース、networks flags 表示、diff 色分け、etag ポーリングによる自動リロード | dev server + api-proxy で mddo-fw デモデータを表示・確認できる |
| 4 | dependency Viewer | 共通部品を再利用してレイヤ帯表示を実装。複数の表示案があれば比較して決める | トレース経路の強調が機能する |
| 5 | コンテナ化・統合 | 静的成果物 + nginx のイメージ (volume なし)。api-proxy に `/netoviz2/` と gzip を追加。`localhost:15000/netoviz2/:nw/:ss/` で確認。現行 netoviz と並行稼働し、デモデータで機能比較 | 現行との機能比較結果の報告 |
| 6 | 移行判断 | 機能が十分なら playground のサブモジュール登録。index 更新スクリプト・`docs/architecture.md` などを更新 | サブモジュール登録、ドキュメント更新 |

### 進捗 (2026-11-02)
* 段階 1: 仕様のドラフトを作成済み ([docs/netoviz2_data_format.md](../../netoviz2_data_format.md))。
* 段階 2 (netomox-exp): **実装済み・レビュー反映済み** (未コミット)。
  * ブランチ: `repos/netomox-exp` の `feature/netoviz2` (起点は稼働中のコンテナ・gem 0.15.0 と同じ前提の `v1.21.0-dev`。要求書の「main HEAD (v1.20.0)」から変更し、確認済み)。
  * 追加: `lib/netoviz2/` (ID 生成、モデル、レイヤ依存・rank、各ビルダー、キャッシュ)、`lib/api/helpers_netoviz2.rb`、`lib/api/topologies/network/snapshot/netoviz2_api.rb` (`snapshot.rb` に mount を 2 行追加)。API: `summary` / `layers/:layer` / `supports` / `attributes`。
  * テスト: 既存 201 例 + 新規 74 例 = 275 例が成功 (1 例は gem 修正のリリースまで pending)。rubocop 指摘なし。
  * 実データ (mddo-fw / mddo-mregnw / mddo-bgp) で稼働中の環境から API の動作を確認済み (api-proxy 経由、304 を含む)。
  * `code-reviewer` のレビュー結果を反映済み: link の ID に `~link` マーカーを追加して node との衝突を排除 (`~` も常にエンコード)、POST attributes は 304 を扱わず `200`、builder の例外を JSON の 500 とログに、`ids` の型不正を 422、循環警告を循環内に限定、ETag にスキーマ版を含める、キャッシュのテスト間リセット、など。仕様書の不一致も修正。
  * gem の往復確認と規模の計測の結果は仕様書の 11 に記載。想定上限 (30,000 TP) では 1 リクエスト約 2.8 秒 (キャッシュなし)、layer 応答 2.5MB (gzip で 222KB)。キャッシュを入れ、gzip は段階 5 で追加する。
* **netomox gem の修正** (別リポジトリ `/home/hagiwara/ool-mddo/netomox`、ブランチ `fix/attribute-diff-state`、`v0.15-dev` から作成。**v0.15.1 としてリリース済み** (CI で gem 登録を確認)):
  * 属性・support の `_diff_state_` を読み込み時に復元する (`DiffState.from_data` を追加、`AttributeBase` で復元)。`DiffState#to_data` / `#to_s` が `pair` に文字列 (復元後の値) を持つ場合に落ちる問題も修正。
  * 実データ (`mddo-ospf/emulated_diff`) で、修正前は属性内の差分 0 件・support の `pair` 0 件、修正後は 1 件・118 件が復元されることを確認。
  * テスト: gem 側 347 例 + 新規 10 例 = 357 例が成功、rubocop 指摘なし。修正した gem を netomox-exp のテストに適用しても 274 例が成功 (回帰なし)。
* **残作業 (段階 2 関連):**
  * (済) netomox v0.15.1 をリリースし、netomox-exp の Gemfile を `>= 0.15.1` に更新。netomox-exp のブランチは `v1.22.0-dev` (旧 `feature/netoviz2`。イメージタグにするためスラッシュなし) で、CI がイメージを build 済み。
  * gem 側の修正候補 (任意): node 直下の `flag`、bgp-proc 属性の一部 (BGP ポリシー関連)。
  * 低優先度の指摘 (未対応): ModelCache が構築中に他の snapshot のキャッシュヒットも待たせる (キーごとのロック)、トポロジ書き込み中に読むと一時的に 500 になりうる (書き込み側を一時ファイル + rename にする案は既存コードの変更を伴う)。
* 段階 3 (netoviz2 MVP): **実装済み** (`repos/netoviz2`、独立リポジトリ、ブランチ `v0.1.0-dev`、コミット済み。リモートは未設定)。
  * 構成: Vite + Vue 3 + TypeScript の SPA (Pinia、vue-router、d3-force/zoom/drag)。UI ライブラリなし。実行時の依存の脆弱性は 0 件。
  * 機能: network/snapshot 一覧、サマリ (flags・diff 印・警告)、レイヤの表示切替 (URL の `?layers=`)、force-simulation 表示 (ノード単位、ダブルクリックで term-point 展開)、オブジェクトの選択 (URL の `?sel=`) と support トレースの強調 (上位/下位レイヤ・トレース方向の切替)、右パネルに属性・diff (汎用 JSON ツリー、diff_data の before/after 表示)・上位/下位レイヤのオブジェクト一覧 (クリックで選択)、5 秒ごとの ETag 確認による自動リロード。
  * テスト: 123 例すべて成功 (単体 + コンポーネント + 画面)。`typecheck` / `lint` / `build` も通る。
  * 動作確認: 開発サーバ (api-proxy へプロキシ) + ヘッドレス Chrome で実データ (mddo-fw) を表示。選択・トレース・展開・属性パネル・自動リロード (データ更新で 54 → 55 ノード) を確認。
  * 今後の課題: 想定上限 (30,000 TP) での描画性能の計測 (SVG + ノード単位表示で足りるか。必要なら Cytoscape.js / Canvas を検討)、既定の表示レイヤ (小さなトポロジでは全レイヤを同時に表示するため、レイヤ数が多いと見づらい)、ラベルの重なり、ダークモード。
* 段階 5 (コンテナ化・compose 統合・gzip): **実施済み** (段階 4 より先に実施)。
  * `repos/netoviz2`: `Dockerfile` (node 24.22.2 でビルド → nginx 1.30.6-alpine で `/netoviz2/` 配下に静的配信、volume なし)、`nginx.conf` (SPA のフォールバック、hash 付きファイルの長期キャッシュ、gzip)。
  * playground (未コミット。`docker-compose.yaml` などにユーザーの未コミットの変更が混在しているため): `.env` に `NETOVIZ2_IMAGE` / `NETOVIZ2_IMAGE_TAG=v0.1.0-dev`、`docker-compose.yaml` に `netoviz2` サービス (`build` あり、`api-proxy` の `depends_on` に追加)、`assets/api-proxy/default.conf` に `/netoviz2/` の転送・`/netoviz2` の相対リダイレクト・netoviz2 API (`/topologies/:nw/:ss/netoviz2/...`) だけの gzip (他の API は変更なし)。`docs/architecture.md` に netoviz2 を追記。
  * 確認: `http://localhost:15000/netoviz2/` で一覧・表示・選択まで動作 (ヘッドレス Chrome)。JS は 182KB → 75KB、layer 応答は 92KB → 13KB に圧縮。gzip 経由 (弱い ETag) でも条件付きリクエストが 304 になる。既存の API・netoviz (3000) に影響なし。
* 手動確認のフィードバックへの対応 (段階 3・5 の後):
  * 導線: 一覧 (ネットワーク) → ネットワーク (スナップショット一覧) → 表示、の階層に変更。ヘッダーにパンくず (netoviz2 / ネットワーク / スナップショット (同じネットワークのスナップショットを切り替えるセレクタ))。サマリのネットワーク名もリンク。
  * term-point: ノードの円周上のポートとして表示 (既定で全ノード。表示中のレイヤの TP が 1000 を超えると既定で非表示)。相手ノードの方向に向け、リンクはポート間に描画。TP を選択すると属性・support を右パネルに表示。チェックボックスとノードのダブルクリックで表示/非表示を切り替え。ポート名はズームイン時または選択・トレース時に表示。
  * レイアウト: ウォームアップ + 複数回の初期化から交差・重なりが最小のものを採用 (7.8.1 の A)。代替案は 7.8.1。
  * テスト: 157 例すべて成功。コンテナも作り直し済み (`http://localhost:15000/netoviz2/`)。
  * ホバーとラベル: マウスオーバーした要素 (ラベル上を含む) を強調・最前面に出し、つながるリンクも強調。ラベルのクリック・ダブルクリックも要素への操作として扱う (実ブラウザのマウス操作で確認)。テスト 167 例成功。
* レイアウトエンジンの検証 (7.8.2): **実施済み**。force (d3) と ELK (layered / stress / force) を実装し、URL (`?layout=` / `?compare=`) とツールバーで切り替え・左右比較できる (交差数・重なり・所要時間を各パネルに表示)。実データで比較した結果、ELK stress が総合的に最良、layered は階層的なトポロジ向き。リンクは ELK の経路 (折れ点) で描画。force は交差が 0 になるまで再試行し、レイヤが揃ってから配置する。テスト 215 例成功。
* レイアウトエンジンの決定: **force (d3-force) と自前の stress を採用 (既定は stress)、ELK は採用しない。** ELK 関連のコード・依存 (elkjs)・折れ点の経路描画を削除した。エンジンは URL の `?layout=<stress|force>` で切り替え、`&compare=<engine>` で並べて比較できる (他の値は無視して既定にする)。設計・経緯・ELK のライセンス分析は [design_notes/netoviz2_layout.md](../../design_notes/netoviz2_layout.md)。テスト 212 例成功。
* 手動確認のフィードバックへの対応 (3 回目): **MIT の `LICENSE` を netoviz2 に追加** (`package.json` にも `license: MIT`)。ライト/ダークの切り替え (ヘッダー右の Auto / Light / Dark。選択はブラウザに保存。色は `styles/theme.css` の変数で一元管理し、`color-scheme` と `light-dark()` を使う)。レイヤ一覧に「Select all / Clear all」。ネットワーク一覧・スナップショット一覧の、リンクと文字の間隔。テスト 223 例成功。
* 段階 4 (dependency (レイヤ帯) Viewer) 以降: 未着手 (段階 4 は後で実施)。

* 変更は小さな単位に分割し、各ステップで関連テストを実行する。
* 既存インタフェース (netomox-exp の既存 API、現行 netoviz) は維持する。

# 9. リスクと未確認事項

## リスク
* 現行機能の再実装による欠落・回帰 → 並行稼働と機能比較で緩和。
* 大規模時の Ruby 側処理時間・応答サイズ・描画性能 → 段階 2 の早期計測と、構造/属性の分離・LOD で緩和。
* 描画ライブラリの選択ミス → 描画部分を差し替え可能な構造にして緩和 (7.8)。

## 未確認事項
* コンテナ内にインストールされた netomox gem のバージョン・内容 (調査したのはローカル checkout の 0.15.0)。整形処理は gem を使うため、gem の版により読み込める属性・動作が変わる。段階 2 の最初に確認する。
* netoviz の dependency / dependency2 の詳細、`dependency2` が使う API。
* テストの実行結果 (netoviz / netomox-exp とも未実行)。
* state-conductor 等、netoviz URL を参照する可能性のある箇所 (`demo/copy_to_emulated_env/env/cmdline` の `netoviz_url` の利用先)。
* diff 入りトポロジの生成側 (model-conductor 等) の運用。ただし netoviz2 は `_diff_state_` の有無のみで処理を切り替えるため、設計には影響しない。

---

# 付録: 副次的に見つかった既存ドキュメントの不一致 (今回は修正しない)
* `docs/architecture.md` は netomox-exp を「Ruby/Sinatra」と記載しているが実装は Grape。また netoviz が `GET /topologies/...` で取得するように読めるが、実際は共有 volume 経由。
* `repos/netomox-exp/docs/architecture.md` の ns_convert_table の記述 (パス、保存場所) が実装 (`/topologies/:nw/:ss/ns_convert_table`) と異なる。
* netoviz の `MDDO_TOPOLOGIES_DIR` 環境変数はコード上参照されず、`static` がハードコードされている。
