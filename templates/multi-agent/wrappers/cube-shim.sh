# cube-shim — ローカル実行シム（subaco-shim serve = subaco_shim.cli:main）を起動する。
# hive-mcp ラッパーと同型。
#
# 依存の完全固定: テンプレート同梱の requirements-shim.txt（リリース時の uv export 産物）が
# あれば --with-requirements で推移依存をピン留めする。
# dev fallback: SUBACO_SHIM_DEV にローカル subaco-shim のパスがあれば --from で起動する。
#
# 診断出力は SUBACO_SHIM_LOG_LEVEL に従う。ローカル HTTP サーバーのため stdout/stderr 可。
#
# 注: writeShellApplication が shebang と `set -euo pipefail` を自動付与するため、
#     本ファイルにはそれらを書かない。

# 指定ファイルを PWD から上方探索する。
find_up() {
  name=$1
  dir=$PWD
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/$name" ]; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
    dir=${dir%/*}
    [ -z "$dir" ] && dir=/
  done
  return 1
}

# 1) dev fallback。
if [ -n "${SUBACO_SHIM_DEV:-}" ]; then
  exec uvx --from "$SUBACO_SHIM_DEV" subaco-shim serve
fi

# 2) ピン留め requirements があれば固定して起動。
if req=$(find_up requirements-shim.txt); then
  exec uvx --with-requirements "$req" subaco-shim==0.0.0 serve
fi

# 3) requirements 不在時は素の uvx にフォールバック。
echo "cube-shim: requirements-shim.txt 未検出。ピン留めなしで subaco-shim==0.0.0 を起動します。" >&2
exec uvx subaco-shim==0.0.0 serve
