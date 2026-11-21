#!/usr/bin/env bash
# PreToolUse(Bash) hook: `git commit` の前に、ドキュメント更新チェックを促す。
# 同じステージ内容に対しては 1 回だけブロックし、2 回目以降は通す
# (チェック後にドキュメントを追加ステージすると内容が変わるので、もう 1 回だけ促す)。
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
# `git commit` を実行するコマンドだけを対象にする (git -C <dir> commit 等のサブモジュール操作は対象外)
printf '%s' "$cmd" | grep -Eq '(^|[;&|(]|&&)[[:space:]]*git[[:space:]]+commit([[:space:]]|$)' || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
seen="$root/.claude/.docs-check-seen"
key=$(git diff --cached | sha256sum | cut -d' ' -f1)
if [ -f "$seen" ] && grep -qx "$key" "$seen"; then
  exit 0
fi
echo "$key" >> "$seen"
cat >&2 <<'MSG'
コミット前のドキュメント更新チェック (docs/README.md の運用ルール参照)。
`git diff --cached` の内容を踏まえ、次を確認してから、同じコミットコマンドを再実行すること。
1. 変更に関連する docs/ の spec・plan・investigation・todo の status と本文の状態記述
   (「未コミット」「未実施」など) が、今回の変更と食い違っていないか。食い違うものは更新する。
2. 新規・変更した docs/ の文書に front matter (topic/type/status/related) があり、
   docs/README.md の索引に載っているか。
3. CLAUDE.md・README などの入口文書 (サービス構成・コマンド・制約) に影響する変更がないか。
更新したら `git add` してコミットに含める。更新不要なら、その旨をユーザーに一言伝えてよい。
MSG
exit 2
