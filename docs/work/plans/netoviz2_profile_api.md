# ダイアグラムプロファイルの扱いの見直し (複数 snapshot への適用 + netomox-exp 経由の配信)

状態: **方針承認済み (論点 E は 2026-11-06 に決定)。実装は P0 から、段階ごとに確認して進める**

## 0. 決定事項

| #   | 決定                                                                                                                                                                      |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 置き場所は B1: `profiles/` を残し、新しいボリュームとして netomox-exp に渡す                                                                                              |
| 2   | `?profile=` が無くても、合えば自動で使う。**どのプロファイルを使っているかを、netoviz2 の画面で明示する** (論点 D)                                                        |
| 3   | netoviz2 のビルド埋め込み作業用コピー (`src/profiles/`) は廃止する                                                                                                        |
| 4   | `target.snapshot` は正規表現 (全体一致)                                                                                                                                   |
| 5   | 今回は `emulated_asis` 用のプロファイルだけ作って動作確認する。conduit 系などは後で検討                                                                                   |
| 6   | `profiles/` の中身 (人が書く) は YAML。**netoviz2 ↔ netomox-exp の API は JSON**。YAML → JSON の変換は netomox-exp が持つ。netoviz2 は YAML を読まない (パーサを持たない) |

netoviz2 の schematic レイアウトで使うダイアグラムプロファイル (以下プロファイル) について、次の 2 点を見直す。

1. 1 つのプロファイルを複数の snapshot に適用できるようにする (置き場所と対応づけ)。
2. プロファイルを、netoviz2 にバンドルした作業用コピーではなく、netomox-exp の API 経由で渡す (README に書いた「最終形」)。

書式そのもの ([profile_format.md](../../../repos/netoviz2/docs/design/profile_format.md)) は、`target.snapshot` を足す以外は変えない。

## 1. 現状 (調査結果)

| 項目                   | 現状                                                                                                                                                              |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 選択                   | URL の `?profile=<名前>` で明示。`profileFor(view, layer)` が `view` と `target.layer` だけで選ぶ。**snapshot は見ない**。`target.network` は読むだけで検査しない |
| 読み込み               | `bundledProfileSource` が `src/profiles/*.yaml` をビルドに埋め込む (`import.meta.glob`)。`ProfileSource = (name) => Promise<text \| undefined>`                   |
| 正本                   | `playground/profiles/<network>/<snapshot>/profile.yaml`。netoviz2 には**作業用コピー**を手で同期                                                                  |
| 複数 snapshot への適用 | プロファイル自体は snapshot 非依存なので、`?profile=` を同じにすれば**今でも適用できる**。置き場所の約束 (`<snapshot>/`) と合わないだけ                           |

### 実データでの確認 (`topologies/mddo-fw/`)

| snapshot                   | レイヤ                                          | ノード名                                                                                                                |
| -------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `original_asis`            | layer1 / layer2 / layer3 / ospf_area*           | `site-a-br-1`, `site-a-fw-1`, `site-a-cr-1` ... (+ `Seg_*`)                                                             |
| `emulated_asis`            | **layer3 / ospf_area\* のみ (layer1/2 が無い)** | `original_asis` と同じ名前                                                                                              |
| `original_asis_conduit1,2` | layer3 / ospf_area\* のみ                       | `site-a-wan-zone-rt`, `site-a-cr`, `site-a-fw-1`, `site-a-fw-2` (土管化後。`br` が `wan-zone-rt` に、`cr-1` が `cr` に) |
| `emulated_asis_conduit1,2` | 同上                                            | conduit と同じ                                                                                                          |

分かること:

- **`emulated_asis` は `original_asis` と同じ名前**だが、layer1 が無いので、`original_asis` 用のプロファイル (`target.layer: layer1`) は効かない。layer3 を下位レイヤから継承することもできない。layer3 を図にするなら、layer3 用のルールが要る。
- **conduit 系は名前の体系が違う** (`wan-zone-rt` など)。`original_asis` 用の `name` 正規表現はそのまま通らない。別のプロファイルが要る (無ければ推論 → stress)。
- つまり、**プロファイルの単位は「network + snapshot の組 (の集合) + レイヤ」**。`<network>/<snapshot>/profile.yaml` の 1 対 1 は合わない。逆に「network 単位の 1 ファイル」でも足りない (snapshot 群で名前の体系が違う)。

## 2. 設計の論点と案

### 論点 A: プロファイルと snapshot の対応づけ

| 案            | 内容                                                                                                                        | 評価                                                                                                    |
| ------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| A1            | `profiles/<network>/<snapshot>/profile.yaml` (現状)                                                                         | 1 対 1。`emulated_asis` / `original_asis` の同じ定義が複製になる。**却下**                              |
| A2            | `profiles/<network>/profile.yaml` (network 単位) + snapshot 上書き                                                          | conduit 系の別体系を表せず、上書きの規則が増える                                                        |
| **A3 (推奨)** | プロファイルが**適用範囲を宣言**する。`target` に `snapshot` (パターン) を足す。置き場所は `profiles/<network>/<名前>.yaml` | 1 ファイルを複数 snapshot に使える。置き場所と適用範囲が独立。既存の `target` と複数文書 (`---`) の延長 |
| A4            | `profiles/index.yaml` に対応表                                                                                              | 対応が 2 か所に分かれ、同期を忘れやすい                                                                 |

A3 の選択規則 (netoviz2 側。`profileFor` を拡張):

1. `?profile=<名前>` があれば、そのファイルだけを使う (従来どおり)。
2. 無ければ、その network のプロファイルのうち、`view` / `target.snapshot` / `target.layer` が合う**最初のもの** (ファイル名の昇順 → 文書の順) を使う。
3. 無ければ、従来どおり (継承 → 推論 → stress)。

`target.snapshot` の書き方: **正規表現** (全体一致。省略 = 全 snapshot)。`name` が正規表現なので揃える。例: `snapshot: 'original_asis|emulated_asis'`、`snapshot: '(original|emulated)_asis_conduit\d+'`。glob は書きやすいが、`name` と書式が混ざるので採らない。

### 論点 B: 置き場所 (git 管理される正本)

| 案  | 内容                                                                             | 評価                                                                                                     |
| --- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| B1  | 今の `playground/profiles/` のまま。netomox-exp に**新しいボリューム**として渡す | 既存の `queries` / `topologies` / `usecases` / `policies` と同じ作り。人が書くものと自動生成物が分かれる |
| B2  | `playground/topologies/profiles/<network>/<名前>.yaml`                           | **推奨しない**。理由は下                                                                                 |
| B3  | `usecases/` の下                                                                 | プロファイルはユースケースに依存しない (最初に合意済み)。不可                                            |

B2 を推奨しない理由 (調べた事実):

- **`topologies/.gitignore` が `*` (例外は `.gitignore` だけ)**。`profiles/` を置いても git 管理されない。`!profiles/` の例外を足せば管理できるが、CLAUDE.md の「`topologies/` は自動生成で直接編集不可」と矛盾する。
- `topologies/` 直下は **network 名のディレクトリ**として扱われる。`DELETE /topologies/:network` は `rm -rf topologies/<network>` (demo スクリプトが network 単位で消す)。`profiles` という名前の network が出ると衝突する。`_index.json` と同居する形になり、`GET /topologies/index` の登録内容とも無関係。
- コンテナの `topologies` ボリュームは、netomox-exp が**書き込む**(read_only でない)。人が書くものは read_only で渡したい。

B1 の変更点:

- `docker-compose.yaml` に `profiles` ボリューム (`device: ./${SHARED_PROFILES_DIR}`) を追加。netomox-exp に `read_only: true` で渡す。
- `.env` に `SHARED_PROFILES_DIR=profiles` と `MDDO_PROFILES_DIR=/mddo/profiles` を追加。netomox-exp の環境変数に `MDDO_PROFILES_DIR`。
- 置き場所は `profiles/<network>/<名前>.yaml` (`<snapshot>/` ディレクトリは廃止)。`mddo-fw/original_asis/profile.yaml` → `mddo-fw/<名前>.yaml` (名前は例: `asis`)。

### 論点 C: API

プロファイルは **network 単位のファイル群** (YAML)。netomox-exp が YAML を読み、**JSON にして返す**。変換だけを行い、プロファイルの意味の検証 (キーの種類、正規表現、`tier` の参照など) はしない。検証と選択は netoviz2 の責務のまま (プロファイルは「描画の知識」なので、解釈は描画側に置く)。

```
GET /topologies/:network/netoviz2/profiles
→ 200 {
  "network": "mddo-fw",
  "profiles": [                                  // ファイル名昇順
    {"name": "asis", "etag": "...",
     "documents": [ {<プロファイル 1 (YAML の 1 文書)>}, {<プロファイル 2>} ]},
    {"name": "broken", "etag": "...", "documents": [], "error": "(<unknown>): did not find expected key at line 3 ..."}
  ]
}
→ 200 {"network": "...", "profiles": []}       // ディレクトリが無い / 空
```

- `documents`: YAML の文書 (`---` 区切り) ごとに 1 要素。各要素は、YAML の内容をそのまま JSON にしたオブジェクト (キーの名前・構造は [profile_format.md](../../../repos/netoviz2/docs/design/profile_format.md) のまま)。空の文書は除く。
- `error`: **ファイル単位**の YAML 構文エラー。1 ファイルが壊れていても、他のファイルと HTTP ステータスは正常 (netoviz2 が壊れたファイル名とメッセージを表示する)。
- 変換は安全な読み込みだけを使う (任意オブジェクトの生成を許さない。Ruby の `Psych` の safe 系。`load_stream` 相当の API の有無と動作は実装時に確認)。アンカー・エイリアスは許さない/許すを実装時に決める (使わない前提)。
- YAML の型はそのまま JSON に出る。例: 引用符なしの `01` は数値 `1`、`'01'` は文字列。**型の検査 (数値が来たら警告) は netoviz2 の `parseProfile` が従来どおり行う** (入力が YAML のテキストか JSON のオブジェクトかの違いだけ)。
- `etag`: ファイルの mtime (ns) と size (既存 netoviz2 API と同じ作り)。
- 1 回の呼び出しで network の全ファイルを返す (数個・数 KB)。`?profile=` 指定時も同じ応答から名前で引ける。
- 対象は `<MDDO_PROFILES_DIR>/<network>/*.{yaml,yml}`。`<network>` もパス要素として検査する。
- ファイル名 (拡張子を除く) は `[A-Za-z0-9_.-]+` に限り、それ以外のファイルは返さない。
- URL の形: 既存は `/topologies/:network/:snapshot/netoviz2/*`。プロファイルは snapshot 非依存なので `/topologies/:network/netoviz2/profiles` にする。`snapshots` (`/topologies/:network/snapshots`) と同じ流儀で、`netoviz2` という名の snapshot とは衝突し得るが、実在しない前提とする (Grape のルート定義順で固定セグメントを先にする)。
- api-proxy: `/topologies/` は既にプロキシされているので追加は不要のはず (実装時に確認)。
- 書き込み API (PUT) は作らない。編集は git 上の YAML で行う (YAGNI)。

### 論点 D: netoviz2 側の変更

- **YAML を読む機能を持たない。** `parseProfiles(text)` (`yaml` の `parseAllDocuments`) をやめ、API が返す `documents` (JSON のオブジェクト) を `parseProfile(value, warnings)` に渡す。検証の中身 (キー・型・正規表現・警告) は変えない。`ProfileError` は API の `error` にも使う。
- `ProfileSource` を、`(name) => text` から **network 単位の取得** (`(network) => Promise<ProfileFile[]>`) に変える。`ProfileFile = { name, etag, documents, error? }`。既定のソースは `fetch` (同一オリジンの `/topologies/:network/netoviz2/profiles`)。テストは `ProfileSource` を注入する。
- ビルド埋め込み (`src/profiles/`、`import.meta.glob`、`bundledProfileSource`、`profileSourceOf`) と `src/profiles/README.md` を**削除**する。API が無い・404 の環境は、プロファイルなし (継承 → 推論 → stress) で動き、警告を出す。
- `target.snapshot` (正規表現、全体一致) と `target.network` の検査は、**読み込み時** (`loadProfiles` → `profileInScope`) に行う。`selectProfile` は従来どおり view とレイヤだけを見る。snapshot が分からないときは `target.snapshot` を検査しない。不正な文書 (不正な正規表現を含む) は、自動選択のときは**文書単位**で警告にして使わず、`?profile=` で指定したファイルは全体をエラーにする。`loadProfiles` は `profiles` に加えて `entries: [{file, index, profile}]` を返す (使用中の表示用、P4)。
- 取得は network ごとに 1 回 (キャッシュ)。ページの再読み込みで最新になる。
- **何が使われているかを明示する** (決定 2):
  - レポート (`SchematicReport`) に、`profile: { file, view, index, how }` を足す。`how` は `'explicit'` (`?profile=` で指定) か `'auto'` (`target` に合った)。`index` はファイル内の文書の番号。
  - `SchematicReportPanel` に、レイヤごとに「`asis.yaml` #2 (view: physical, layer: layer3, snapshot: ...) — 自動選択」のように表示する。既存の `source` (profile / inherited / inferred / none) の表示は、その隣に残す。
  - 合うプロファイルが無いときは、「プロファイルなし (network のファイル N 個のうち、どれも合わない)」と理由を表示する。壊れたファイル (`error`) と、無視した文書 (警告) も一覧に出す。
  - 画面の URL は変えない (自動選択を URL に書き戻さない)。再現が必要なときは、パネルの表示と `?profile=` で足りる。

### 論点 E: 決定済みと残りの確認

決定済み: §0 の 1〜6。

決定 (P0 の前に確認済み):

1. **推論の下書きの出力形式:** `yaml` の `stringify` は残す (書き出し専用。読む機能は持たない)。
2. **YAML の書き方:** JSON で表せない書き方 (アンカー・エイリアス・タグ) は使わない。netomox-exp は safe 読み込みで、使われていれば `error` にする。
3. **`emulated_asis` の layer3 の `Seg_*`:** 書式は拡張しない。**下位レイヤの候補が無く**プロファイルで配置するとき (推論と、継承できるレイヤは対象外: 例外の報告を残すため)、階層を持たず階層を持つ 2 つ以上のノードとつながるノードを、接続点として機器の間に置く (エンジンの変更。2026-11-06 に承認、P3 で実施。交差は 656 から 11)。

## 3. 作業の分割 (小さい単位。段階ごとにテスト・確認)

| 段階 | リポジトリ                 | 内容                                                                                                                                                                                                     | 確認                                                                     |
| ---- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| P0   | netoviz2 docs / playground | 方針の文書化: `profile_format.md` に `target.snapshot`・選択規則・JSON の形を追記、`profiles/README.md` の置き場所を更新、`netoviz2_data_format.md` に API を追記                                        | リンク検査、prettier                                                     |
| P1   | netoviz2                   | `parseProfiles` を JSON の入力に変更 (YAML のパースを削除)、`target.snapshot` と選択規則 (`selectProfile` / `profileFor`)、`ProfileSource` の型変更。バンドル版は、P4 まで一時的に新しい型で包んで動かす | 単体テスト (YAML のテストデータをオブジェクトに変換)                     |
| P2   | netomox-exp                | `GET /topologies/:network/netoviz2/profiles` (ヘルパー、API、spec)。`MDDO_PROFILES_DIR`。YAML → JSON の変換 (safe 読み込み、ファイル単位のエラー)                                                        | rspec、rubocop                                                           |
| P3   | playground                 | `profiles` ボリューム (compose、`.env`)、ファイル移動 (`mddo-fw/original_asis/profile.yaml` → `mddo-fw/asis.yaml`、`target.snapshot` を追記)、**`emulated_asis` の layer3 用のプロファイルを追加**       | `docker compose config`、API の実呼び出し                                |
| P4   | netoviz2                   | API のソース (`fetch`)、自動適用、使用中のプロファイルの明示 (レポート・パネル)、バンドル版・`src/profiles/` の削除                                                                                      | テスト、実機 (`original_asis` と `emulated_asis` の `?layout=schematic`) |
| P5   | 各リポジトリ               | 文書の更新 (`architecture.md`、`development.md`、`agent_guide.md`、playground の `CLAUDE.md`、`docs/design_notes/development.md`、`profiles/README.md`)                                                  | リンク検査                                                               |

依存: P1 と P2 は独立。P3 は P2 の後。P4 は P1 と P2 と P3 の後。各段階の後に、`code-reviewer` でレビューし、報告してから追加の修正をする。

ブランチ: netomox-exp は `v1.22.0-dev` (作業用の既存ブランチ)。変更は netomox-exp / netoviz2 / playground の 3 リポジトリにまたがる。リリース順は release-submodule / release-playground の手順に従う (netomox-exp → netoviz2 → playground のイメージタグ更新)。コミットは、その都度指示を受けてから行う (playground は指示があるまでコミットしない)。

## 4. リスク・注意点

- **リリースの順序:** netoviz2 が API を前提にすると、古い netomox-exp では 404。404 は「プロファイルなし」として扱い、警告だけにする (動作は継承 → 推論 → stress)。
- **プロファイルの検証:** YAML の構文エラーは netomox-exp が `error` として返し、意味の検証 (キー・型・正規表現) は netoviz2 が行って画面に出す。どちらもバックエンドのステータスは正常にする。
- **正規表現の負荷:** `name` / `target.snapshot` の正規表現は、プロファイル由来の入力をブラウザで実行する。信頼できる入力 (git 管理の `profiles/`) を前提とする。`parseProfiles` の TODO (長さの制限) は、API 化後も残る。
- **正本の移動 (`<snapshot>/profile.yaml` → `<名前>.yaml`):** playground は未コミットの `profiles/` がある。移動は P3 でまとめて行う。
- **GitHub リンク:** netoviz2 の文書から playground の文書へのリンクは `blob/main`。playground のリリースまで切れる (従来どおり)。
- **キャッシュ:** プロファイルを直したとき、ブラウザの再読み込みで反映する (ファイルは毎回読む)。ホットリロードは作らない。

## 5. 確認が必要な事項 (実装前)

- 決定済み (§0、論点 E)。残りは、P3 で `Seg_*` の扱いを試した結果の確認だけ。
- api-proxy が `/topologies/:network/netoviz2/profiles` を通すこと (nginx 設定の確認)。
- Grape で `:network/netoviz2/profiles` と `:network/:snapshot` のルートの優先順位 (spec で確認する)。

## 6. 実装結果と計画との差分 (P4 まで)

- **使用中のプロファイルの表示:** `SchematicReport` には持たせず、ForceView が、取得した `entries` から `selectProfile` で求めて、パネルに渡す (`file #index (by target | named)`、継承のときは継承元のプロファイル)。選択のロジックは renderer と同じ (view なし)。view を使うようになったら、レポートに持たせる形に直す。
- **注記:** 合うものが無いときは「no profile applies to this network / snapshot」。ファイル数は出さない。壊れたファイル・使わなかった文書は、ツールバーのエラー表示 (`file #index: ...`) に出す。
- **取得のキャッシュ:** ForceView の 1 インスタンス (= network / snapshot) ごとに、ファイル名 (`''` は全部) をキーに、読み込み結果を持つ。エンジンの切り替えで再取得せず、同じ配列を renderer に渡す (再配置しない)。
- **エンジンの切り替え:** schematic に切り替えるときは、下位レイヤとプロファイルの両方を待って、1 回だけ配置する。schematic 以外では、`?profile=` が無ければ取得せず、renderer のプロファイルも変えない。
- **API の形の検査:** `getProfiles` が、配列でない応答を 502 にし、404 を「バックエンドにプロファイル API が無い」と分かるメッセージにする。
