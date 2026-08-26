# hive-mcp のクライアント別登録手順

チーム協業のメモリ（メッセージ・長期記憶）を提供する `hive-mcp` を、各コーディングエージェントへ
登録する手順。**Claude Code は追加設定なしで動く**（`.mcp.json` を読む）。Codex / Gemini CLI は
`.mcp.json` を読まないため、ベンダー別の設定が要る。

> **重要（全クライアント共通）:** ベンダー別設定は**ユーザーグローバル**であり、direnv 有効シェルから
> 起動しても **MCP 子プロセスへの環境変数の伝播はクライアント実装依存で保証されない**。
> このため下記の雛形はいずれも `HIVE_DB_PATH` と `HIVE_TEAM` を**絶対パス・明示値**で書く。
> 複数プロジェクトで使う場合は、プロジェクトごとに別のサーバー名（`hive-<project>` 等）で登録する。

`HIVE_TEAM` の値は devShell 内で `echo "$HIVE_TEAM"`（`.envrc` が `hive-team` から導出・エクスポート）、
`HIVE_DB_PATH` は `<プロジェクト絶対パス>/.hive/messages.db` で確認できる。

## Claude Code

同梱の `.mcp.json` がプロジェクトスコープで読まれるため**設定不要**。初回はプロジェクトの MCP
サーバーを信頼するか確認される。

## Codex（`~/.codex/config.toml`）

```toml
[mcp_servers.hive]
command = "hive-mcp"
args = []
# 非対話実行（codex exec）で MCP ツール呼び出しが自動キャンセルされるのを防ぐ。
# 既定のままだと承認プロンプトを出せず "user cancelled MCP tool call" になる（実測）。
# "auto" ではキャンセルされるため "approve" を指定すること。
default_tools_approval_mode = "approve"

[mcp_servers.hive.env]
HIVE_DB_PATH = "/absolute/path/to/your-project/.hive/messages.db"
HIVE_TEAM = "your-team"
HIVE_LOG_LEVEL = "info"
```

`hive-mcp` は devShell が提供するラッパーであり、Codex を devShell の外から起動する場合は PATH に
無い。その場合は `command` に絶対パス（`nix develop -c which hive-mcp` で確認）を書くか、
`command = "nix"` / `args = ["develop", "/absolute/path/to/your-project", "-c", "hive-mcp"]` とする。

**注意（実測）:** 認証情報は既定の `CODEX_HOME`（`~/.codex/auth.json`）にあるため、**専用の
`CODEX_HOME` を作ってそこに設定を置くと 401 Unauthorized になる**。設定を切り替えたい場合は
`codex exec -c 'mcp_servers.hive.command="…"' …` のように既定ホームへ `-c` で重ねる。

## Gemini CLI（`.gemini/settings.json`。任意）

```json
{
  "mcpServers": {
    "hive": {
      "command": "hive-mcp",
      "args": [],
      "env": {
        "HIVE_DB_PATH": "/absolute/path/to/your-project/.hive/messages.db",
        "HIVE_TEAM": "your-team"
      }
    }
  }
}
```

## 参加とメンバートークン（全クライアント共通）

初回の `hive_join` で**メンバートークン**が発行される。以後、同じ名義で参加するには
このトークンの提示が必要で、未提示・不一致の join は拒否される（名義の乗っ取り防止）。

- **セッションごとに新しいプロセスになるハーネス**（`codex exec` / `claude -p` 等の単発実行）では、
  発行されたトークンを保管し、次回以降の `hive_join` に `token="…"` として渡す。
- トークンを失った場合はホスト管理者が復旧する:
  `hive admin reset-token <team> <name>`（新しいトークンが表示される）。
- 許可リスト（`~/.config/subaco/<team>/trusted_agents`、リポジトリ外）に名義を書いておくと、
  その名義は初回参加時に `trust=1` になる。リスト外の参加者は `trust=0` となり、その投稿は
  他メンバーの既定 `hive_inbox` に**本文が配送されない**（メタデータ通知が一度だけ届く）。
