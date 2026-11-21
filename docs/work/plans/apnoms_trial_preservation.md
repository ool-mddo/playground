# apnoms-trial の保存と作業ブランチ整理

状態: 手順 2・3 は実装済み (ブランチ `apnoms-demo-archive`、未 push)。手順 1 (runner のマージ・タグ) と手順 4 (ブランチ削除) は未実施。

実装で判明した点 (調査時の記述の訂正・追加):

- `project/playbooks/step2-1.yaml` は「削除」ではなく 53 行の削除 (内容の縮小)。ファイルは残っている。
- trial の `docker-compose.min.yaml` は、main で削除済みの `assets/api-proxy/min.conf` を参照していた。`demo/apnoms-trial/assets/` に複製した。
- trial の `docker-compose.min.yaml` は `./repos/*` を bind mount していた (v2.1.1 当時の repos がイメージと一致していた)。main の `repos/*` は新しくイメージと一致しないため、複製版では削除した。
- compose を `demo/apnoms-trial/` から実行するため、`.env` 相当を `apnoms.env` として保存し、`SHARED_*_DIR` を `../../` 付きにした。compose の project 名は `name: playground` で固定 (`demo_vars` の `API_BRIDGE=playground_default`)。
- ローカル clone の `configs/mddo-mregnw` は触らず、`git update-index --cacheinfo` と `.gitmodules` の追記だけで submodule を登録した。

## 目的

- APNOMS 向けの実験・データ取りで作った `apnoms-trial` ブランチの「最終的に使ったもの一式」を、main のリリース状況 (v2.12.x) を壊さずに、再利用可能な形で保存する。
- main 以外の作業ブランチをなくす。
- mddo-mregnw のネットワーク定義とデモ手順も保存する。
- 実験で使った mddo-ansible-runner `v3.1.0-apnoms` を main に取り込み、タグで保全する。

## 決定事項

- `apnoms-trial` の**履歴は保存しない**。最終状態の一式が保存され、再利用できればよい。
- 保存先は `demo/apnoms-trial/`。**実行可能なスクリプト一式をその中に完結させる**。`demo/copy_to_emulated_env` との内容重複は許容する。
- main から削除済みで trial が使う `docker-compose.min.yaml` など、main と衝突するものは `demo/apnoms-trial/` 側に用意する (main のルートには戻さない)。
- ドキュメント (APNOMS 用のデモ手順を含む) は新規に作成する。
- mddo-mregnw は playground のサブモジュールとして追加してよい。ただし**実行までは触らない**。mddo-mregnw のブランチ名は変更せず、そのまま残す。
- mddo-ansible-runner: `v3.1.0-apnoms` を **main にマージし、`v3.1.0-apnoms` タグを付ける**。

## 調査結果

### playground (`origin/apnoms-trial`)

- v2.1.1 (`5d5b230`) から分岐。trial 16 コミット先行 / main 42 コミット先行。先頭は `e449c42`。
- v2.1.1 との差分は 25 ファイル (+810/-188)。
  - 追加 (互換性に影響しない):
    - `demo/copy_to_emulated_env/run_logs/` (gnuplot / python / `topo_specs.sh`)
    - `demo/multi_region_expr/multi_region/` (グラフ定義)
    - `run_all_demos.sh`, `demo_task.sh`, `demo_wait.sh`
    - `network_index/mddo-mregnw.json`
    - submodule `configs/mddo-mregnw` (`8cddf9b`)
  - 破壊的:
    - `demo_step1-2.sh` / `demo_step2-1.sh` / `demo_step2-2.sh` の書き換え
    - `project/playbooks/step2-1.yaml` 削除、`step2-2.yaml` 大幅書き換え
    - `ansible.cfg` の `project/` への移動
    - `demo_vars` (`NETWORK_NAME=mddo-mregnw`, `ANSIBLE_RUNNER_IMAGE=...:v3.1.0-apnoms`)
    - `docker-compose.min.yaml` の拡張
- `repos/*` と `.env` は v2.1.1 当時のまま (例: netomox-exp v1.13.0。main は v1.22.0)。再現に必要なため、イメージタグ情報を `demo/apnoms-trial/` 側に保存する必要がある。
- main へ merge すると衝突し (`.gitmodules`、`docker-compose.min.yaml`)、現行デモ (step2 系) も壊れるため merge はしない。
- リモートのブランチは `main` と `apnoms-trial` のみ。ローカルには `apnoms-trial` と、リモート削除済みの `schematic-profiles` が残っている。

### mddo-ansible-runner (`v3.1.0-apnoms`)

- main から 2 コミット先行 (`eb7edfe`, `a8c9a8e`)。main 側の未取り込み変更はなく、**マージは fast-forward で衝突なし**。
- 変更内容:
  1. 機能追加: `ansible.cfg` / `context/_build/ansible.cfg` に `callbacks_enabled = profile_tasks`、`requirements.yml` に `ansible.posix` を追加。全 playbook 実行でタスクごとの所要時間が出力される (APNOMS の時間計測用)。
  2. ビルド修正: Dockerfile に `PIP_BREAK_SYSTEM_PACKAGES=1`、`context/_build/scripts/pip_install` 追加、`ensurepip` 削除、`introspect.py` を新しい ansible-builder 出力に差し替え。実行時の挙動は変わらない。
  3. 副次: 重複ファイルと見られる小文字 `readme` (77 行) の削除 (`README.md` は残る)。一部ファイルの権限が 755 → 644。
- main に入れた場合の影響: playbook の動作には影響しない。実行ログにタスク時間の行が増える (ログを機械パースしている箇所があれば影響)。`ansible.posix` 追加でイメージがやや大きくなる。
- CI (`.github/workflows/actions.yml`): `on: push` (ブランチ・タグ両方で走る)。イメージは `ghcr.io/ool-mddo/mddo-ansible-runner:${{ github.ref_name }}` として push される (ブランチ名 / タグ名がそのままイメージタグ)。ベースは `ubi9:latest` で、ビルドのたびに再取得される。
  - ビルド後に `delete-package-versions` で、**タグなし (untagged) バージョンのみ**、最新 10 件を残して削除する。タグ付きイメージは消えない。
- playground main の現行デモは `mddo-ansible-runner:v3.1.0` を使用 (`demo/copy_to_emulated_env/demo_vars`)。trial は `:v3.1.0-apnoms`。

### mddo-mregnw

- ブランチ: `main` (= `2region`, `1cf4bc3`) / `5region` / `10region` / `20region` / `40region`。**ブランチ名はそのまま残す**。
- trial が固定している参照 `8cddf9b` (add base configs) は main の履歴上にある。
- ローカルの作業ツリー `configs/mddo-mregnw/` は現在 `2region` ブランチ (untracked の clone)。

## 手順

実行順は 1 → 2 → 3 → 4。削除 (4) は最後に行う。push・タグ・マージ・ブランチ削除は外部に影響するため、各ステップの前に確認する。

### 1. mddo-ansible-runner

1. `v3.1.0-apnoms` を main にマージする (fast-forward)。
2. マージ後の main 先頭に、タグ `v3.1.0-apnoms` を付ける。
3. 同名のリモートブランチ `v3.1.0-apnoms` を削除する (ref が曖昧にならないよう `refs/heads/` / `refs/tags/` を明示して操作)。
4. CI への影響 (調査済み):
   - main への push で `:main` イメージが再ビルドされる (`profile_tasks` 入り)。playground の現行デモは `:v3.1.0` を使うため影響しない。`:v3.1.0` は main への push では再ビルドされない。
   - タグ `v3.1.0-apnoms` の push で `:v3.1.0-apnoms` イメージが再ビルドされる。同名タグは上書きされるが、ブランチ版と内容はほぼ同一 (ベース `ubi9:latest` の更新分のみ差が出うる)。ブランチ削除ではイメージは消えない (CI の削除対象は untagged のみ)。
   - 順序: マージ → タグ push → CI で `:v3.1.0-apnoms` のビルド成功確認 → ブランチ削除。ビルド失敗時にブランチが残っていればやり直せる。

### 2. playground: `demo/apnoms-trial/` の作成 (1 回の PR)

`demo/apnoms-trial/` を新設する。現行の `demo/copy_to_emulated_env` には触れない。

- trial 先頭 (`e449c42`) 時点の `demo/copy_to_emulated_env/` を、実行可能なスクリプト一式として `demo/apnoms-trial/` にコピーする (スクリプト群、`project/`、`run_logs/`、`network_index/mddo-mregnw.json`、`ansible.cfg` など)。
  - `demo_vars` などのパス変数 (`ANSIBLE_RUNNER_DIR` など) は新ディレクトリに合わせて書き換える。
  - `run_all_demos.sh` は `CONFIG_REPO=~/playground/configs/mddo-mregnw` と `SCRIPT_DIR=~/playground/demo/copy_to_emulated_env` をハードコードしている。`SCRIPT_DIR` は `demo/apnoms-trial` に書き換える (`CONFIG_REPO` はそのまま)。
  - `run_all_demos.sh` は `BRANCHES` を順に回し、`git checkout <branch>` で mddo-mregnw のブランチを切り替える。`BRANCHES` は trial 最終版では `("2region")` のみで、他の 4 件はコメントアウトされている。保存時はこのまま (コメントも残す)。
  - 各 step スクリプトはブランチ名を `$1` で受け取る。`demo_task.sh` はブランチ名 (`2region`/`5region`/`10region`/`20region`/`40region`) で traceroute 先 IP を切り替える。
- main の `demo/multi_region_expr/` は**変更しない**。trial でそこに追加されていた 3 ファイル (`multi_region/.gitignore`、`region_data_double.gp`、`region_data_single.gp`。それ以外は main と同一) は、`demo/apnoms-trial/` 配下 (例: `demo/apnoms-trial/multi_region/`) にコピーして保存する。参照パスは新しい置き場に合わせる。
- 衝突するもの・main から削除済みのものを `demo/apnoms-trial/` に用意する:
  - `docker-compose.min.yaml` (trial 版)
  - trial 時点のイメージタグ (v2.1.1 時点の `.env` 相当) を、デモから参照できる形で保存する。
- `demo/apnoms-trial/README.md` (新規) に APNOMS 用のデモ手順を書く:
  - 実行手順 (起動方法・実行順・データ取得とグラフ化)
  - 使用イメージタグ一覧 (playground 各サービス、runner `v3.1.0-apnoms`)
  - mddo-mregnw のブランチ (`2region` / `5region` / `10region` / `20region` / `40region`) と使い分け
  - 現行 v2.12.x のデモとの関係 (互換性がないこと、重複していること)
- main の `docker-compose.yaml`、`.env`、`repos/*`、現行デモには変更を加えない。
- 作業ツリーの無関係な変更 (`demo_vars` のローカル差分、`.claude/skills/...`、`configs/mddo-fw` 等) はコミットに含めない。

### 3. playground: mddo-mregnw をサブモジュールとして追加

- `.gitmodules` に `configs/mddo-mregnw` を追加し、参照先コミットを `1cf4bc3` (mddo-mregnw `main` = `2region` 先頭) に固定する。リージョン別の切り替えは README でブランチ指定を案内する。
- **実行は行わない。** 既存のローカル clone (`configs/mddo-mregnw/`) の中身・ブランチは変更しない。
- 追加方法はローカル clone に影響しないものにする (clone を作り直さない・チェックアウトを変えない)。

### 4. 作業ブランチの削除 (1〜3 の確認後)

- playground: リモートの `apnoms-trial` を削除する。履歴を保存しない方針のため、**削除後は復元できない** (Release PR 経由で `demo/apnoms-trial/` が main に入り、内容を確認済みであることを前提とする)。ローカルの `apnoms-trial` / `schematic-profiles` も削除する。
- mddo-ansible-runner: 1 の手順 3 でブランチ削除済み。
- mddo-mregnw: ブランチはそのまま残す。
- PR 用ブランチは merge 時に削除する。ブランチ名にスラッシュは使わない (CI のイメージタグ制約)。

## 確認事項

決定済み:

- mddo-mregnw submodule の固定先は `1cf4bc3`。
- `demo/multi_region_expr/` は変更しない (trial での追加 3 ファイルは `demo/apnoms-trial/` 側に保存)。

調査済み (旧・未決 1, 2):

- `run_all_demos.sh` は mddo-mregnw のブランチ名を直接参照し、サブモジュールの作業ツリーを `git checkout` で切り替える。submodule の gitlink は `1cf4bc3` (`2region`) に固定するが、実行すると作業ツリーが他ブランチに移り、`git status` に差分が出る。README に次を明記する: 実行後は `git -C configs/mddo-mregnw checkout 2region` で戻す (または `git submodule update` を使う)。
- runner の CI: 上記「CI への影響」のとおり。playground main の現行デモ (`:v3.1.0`) に影響なし。

未決: なし。
