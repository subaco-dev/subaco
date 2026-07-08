# agent-context — vendored agent-context-maintainer への配置非依存エントリ。
#
# a-c-m の実体は subaco リポジトリの vendor/agent-context-maintainer/ に vendored copy として
# 置かれる（取得は段階3の scripts/vendor-acm.sh が担う）。本ラッパーは devShell が提供し、
# プロジェクト内のどのディレクトリから呼ばれても vendored copy を見つけて委譲する。
# shellHook・CI・ドキュメントはすべてこのラッパーを参照する（実体の配置に依存しない）。
#
# 委譲サブコマンド: scaffold / check / sync / skills check。
#
# dev 補助: SUBACO_ACM_DEV に a-c-m のチェックアウト（ディレクトリ）または実行ファイルを
# 指定すると、そちらを優先して exec する。
#
# 注: writeShellApplication が shebang と `set -euo pipefail` を自動付与するため、
#     本ファイルにはそれらを書かない。

# プロジェクトルート（vendor/agent-context-maintainer を含む上位ディレクトリ）を PWD から上方探索する。
find_vendor_root() {
  dir=$PWD
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/vendor/agent-context-maintainer" ]; then
      printf '%s\n' "$dir/vendor/agent-context-maintainer"
      return 0
    fi
    dir=${dir%/*}
    [ -z "$dir" ] && dir=/
  done
  return 1
}

# a-c-m のエントリを解決して exec する（見つからなければ 1 を返す）。
# TODO(段階3): vendor-acm.sh が最終レイアウトを固定した後、候補を実レイアウトへ絞る。
exec_acm() {
  base=$1
  shift
  # 実行可能エントリ候補。
  for cand in "$base/agent-context" "$base/bin/agent-context"; do
    if [ -x "$cand" ]; then
      exec "$cand" "$@"
    fi
  done
  # Python 単一ファイル候補（a-c-m は単一ファイル構成）。
  for py in \
    "$base/agent_context_maintainer.py" \
    "$base/agent_context.py" \
    "$base/__main__.py" \
    "$base/main.py"; do
    if [ -f "$py" ]; then
      exec python3 "$py" "$@"
    fi
  done
  return 1
}

# 1) dev override（SUBACO_ACM_DEV）。
if [ -n "${SUBACO_ACM_DEV:-}" ]; then
  if [ -d "$SUBACO_ACM_DEV" ]; then
    exec_acm "$SUBACO_ACM_DEV" "$@" || true
  elif [ -e "$SUBACO_ACM_DEV" ]; then
    case "$SUBACO_ACM_DEV" in
    *.py) exec python3 "$SUBACO_ACM_DEV" "$@" ;;
    *) exec "$SUBACO_ACM_DEV" "$@" ;;
    esac
  fi
  echo "agent-context: SUBACO_ACM_DEV=$SUBACO_ACM_DEV から a-c-m エントリを解決できません。" >&2
  exit 1
fi

# 2) vendored copy。
if root=$(find_vendor_root); then
  exec_acm "$root" "$@" || {
    echo "agent-context: vendored a-c-m のエントリを解決できません: $root" >&2
    echo "  段階3の scripts/vendor-acm.sh でレイアウトが確定します（TODO）。" >&2
    exit 1
  }
fi

# 3) 未取得（vendor/agent-context-maintainer が存在しない）。
echo "agent-context: a-c-m の vendored copy が見つかりません（vendor/agent-context-maintainer/ 不在）。" >&2
echo "  取得手順: リポジトリ直下で scripts/vendor-acm.sh を実行してください（段階3で追加予定）。" >&2
exit 1
