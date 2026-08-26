# hive-mcp — .mcp.json が呼ぶ command。
# stdio MCP サーバー（subaco-hive = subaco_hive.server:main）を起動する。
#
# 重要: stdout は JSON-RPC 専有。本ラッパーの診断出力は stderr のみに出す。
#
# 依存の完全固定: テンプレート同梱の requirements-hive.txt（リリース時の uv export 産物）が
# あれば --with-requirements で推移依存（zvec・fastembed・mcp SDK 等）をピン留めする。
# dev fallback: SUBACO_HIVE_DEV にローカル subaco-hive のパスがあれば --from で起動する。
#   **extras 必須**: subaco-hive は依存をすべて optional-dependencies に置く設計（本体は
#   stdlib のみで import 可能）。`--from <path>` だけでは mcp SDK も zvec も入らず、
#   「mcp SDK が未導入です」で即終了する（実測）。dev 経路でも [mcp,memory] を明示する。
#
# 注: writeShellApplication が shebang と `set -euo pipefail` を自動付与するため、
#     本ファイルにはそれらを書かない。

# 指定ファイルを PWD から上方探索する（テンプレート同梱ファイルはプロジェクト直下に置かれる）。
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

# 1) dev fallback: 公開前でもローカルソースから起動できる（extras 込み——上記コメント参照）。
if [ -n "${SUBACO_HIVE_DEV:-}" ]; then
  exec uvx --from "${SUBACO_HIVE_DEV}[mcp,memory]" subaco-hive
fi

# 2) ピン留め requirements があれば推移依存を完全固定して起動。
if req=$(find_up requirements-hive.txt); then
  exec uvx --with-requirements "$req" subaco-hive==0.0.0
fi

# 3) requirements 不在時（未リリース dev 等）は素の uvx にフォールバック。
echo "hive-mcp: requirements-hive.txt 未検出。ピン留めなしで subaco-hive==0.0.0 を起動します。" >&2
exec uvx subaco-hive==0.0.0
