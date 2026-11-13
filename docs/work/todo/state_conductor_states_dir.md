# TODO: state-conductor の states ディレクトリ永続化の取り込み

## ステータス

取り込み済み (#121, v2.12.1 以降)。state-conductor v1.1.0 に更新し、`.env` / `docker-compose.visualize.yaml` /
`states/.gitignore` を反映した。残りは「取り込み時にやること」の項目 4 (動作確認) と 5 (リモートブランチ整理) のみ。
(playground の `add_state` は、本 TODO の調査をもとに削除してよい。未削除)

## 背景

playground のリモートブランチ `origin/add_state` (73c7a7c "add states dir for state-counductor",
2024-10-31, 分岐元は v1.15.0 dev) は、state-conductor が出力するデータをホストの `./states` に
永続化するための変更だった。main にはマージされておらず、現在の main は v2.12.0 まで進んでいる。

変更内容 (2 ファイル):

- `.env`: `SHARED_STATES_DIR=states` (ホスト側ディレクトリ) と `MDDO_STATES_DIR=/mddo/states` (コンテナ内パス) を追加
- `docker-compose.visualize.yaml`:
  - state-conductor に環境変数 `MDDO_STATES_DIR` を渡す
  - 名前付きボリューム `states` (`driver_opts`: bind, `device: ./${SHARED_STATES_DIR}`) を `${MDDO_STATES_DIR}` にマウント

## state-conductor 側の対応状況 (調査結果)

(調査時点の記録) 受け側の実装は当時 state-conductor の未リリースブランチにあり、v1.0.2 には存在しなかった。現在は v1.1.0 にリリース済み。

| ブランチ / コミット | 内容 |
|---|---|
| `origin/add_states_dir` (033bf7a, 2024-10-31) | `DATA_DIR = Path(getenv("MDDO_STATES_DIR", Path(__file__).parent))` を追加 (main 未マージ。`add_state` と対) |
| `origin/v1.1.0-dev` (e18bcbb, #13, 2025-03-19) | 同等の変更。出力先を `MDDO_STATES_DIR` 配下にし、`STATE_DIR` を `STATS_DIR` (`stats`) に改名 |

- `main` (v1.0.2) の `src/app.py` が読む環境変数は `PROMETHEUS_URL` のみ。出力先は `src/` 直下の `timestamp` / `state`。
- `main` と `origin/v1.1.0-dev` の差分は e18bcbb の 1 コミットのみ。
- つまり playground 側の `add_state` を取り込むには、state-conductor v1.1.0 (以降) のリリースが前提になる。
  state-conductor 側が `MDDO_STATES_DIR` を読まない版では、この設定を入れても何も起きない。

## states ディレクトリに保存されるデータ

(`origin/v1.1.0-dev` の `src/app.py` を読んだ結果。実際に動かして確認したものではない)

出力先は `${MDDO_STATES_DIR}` 直下の 2 種類。

1. `timestamp/<network>-<snapshot>-<action>.txt`
   - 中身は UTC の UNIX 時刻 (秒) 1 つ。
   - `POST /state-conductor/environment/<nw>/<ss>/sampling` に `{"action": "begin"|"end"}` を送ると作られる。
   - サンプリング中かどうかの判定にも使う (`begin` 二重送信はエラー、`begin` なしの `end` は 404)。
2. `stats/<network>-<snapshot>-stats.json`
   - `end` 受信時に、begin〜end (+20 秒。iperf が流れ切るまでの余裕) の区間のメトリクスを Prometheus (cAdvisor) から取得して保存。
   - 対象は `clab-*` コンテナのインターフェース帯域。`RX_BPS_{AVG,MAX,MIN}` / `TX_BPS_{AVG,MAX,MIN}` (bps)。
   - 形式: `{ノード: {インターフェース: {RX_BPS_AVG: ..., ...}}}`
   - 管理用 IF (`eth0`, `gre*`, `irb*`, `lsi*` など) は除外。`eth1` は `eth1.0` として `ns_convert_table` を引き、モデル側 IF 名 (`l3_model`) に変換。
   - `GET .../<snapshot>/state` と `snapshot_diff` API (snapshot 間のトラフィック比較) で使われる。

`DELETE /state-conductor/environment/<nw>[/<ss>]` で両方とも削除される。

## 永続化の必要性

- 永続化しないと、コンテナ再作成で timestamp / stats が消える。
- stats は評価のたびに再取得できるため、消えて致命的なデータではない。優先度は高くない。
- timestamp は、サンプリング中にコンテナが再作成された場合に begin/end の状態が失われる程度の影響。

## 取り込み時にやること

1. [済] state-conductor v1.1.0 (`MDDO_STATES_DIR` 対応版) のリリース。playground は `STATE_CONDUCTOR_IMAGE_TAG=v1.1.0` に更新済み。
   - その他 v1.1.0-dev での変更点 (e18bcbb 以外に差分はないはずだが、リリース時に再確認)。
2. [済] 古い `add_state` を rebase せず、現在の main から作り直す (約 1 年前のブランチで衝突しやすいため)。
   - `.env` に `SHARED_STATES_DIR` / `MDDO_STATES_DIR` を追加。
   - `docker-compose.visualize.yaml` の state-conductor に環境変数とボリュームを追加。
   - 既存の `SHARED_*_DIR` の命名・配置 (`.env`) に合わせる。
3. [済: `states/.gitignore` で `*` を無視] `states/` の扱いを決める: `.gitignore` に追加するか (自動生成物。`queries/` 等と同様の扱い)。
4. [未] 動作確認: `docker compose -f docker-compose.yaml -f docker-compose.visualize.yaml up -d` で起動し、
   sampling begin/end の POST 後に `./states/{timestamp,stats}` にファイルができること、コンテナ再作成後も残ることを確認。
5. [未] リモートブランチの整理: playground `origin/add_state`、state-conductor `origin/add_states_dir` を削除 (取り込み後、または不要と判断した時点)。

## 未確認事項

- `repos/state-conductor/venv` ディレクトリが追跡対象かどうか。
