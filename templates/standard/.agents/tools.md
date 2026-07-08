## 利用可能ツール

<!-- 生成物: scripts/gen-tool-list.py が agent-tools.nix から生成。
     手で編集しないでください。ツールの増減は agent-tools.nix で行い本スクリプトを再実行します。 -->

devShell（`direnv allow` で有効化）で以下のツールが利用可能です。
推奨慣行: 検索は `rg`、ファイル検索は `fd`、置換は `sd`、タスク実行は `just`（`just test` / `just lint`）を第一候補にしてください。

### コアツール（Tier 1・全テンプレート共通）

- `rg` — コード検索（rg）。検索は grep でなく rg を第一候補にする。
- `fd` — ファイル検索。ファイル検索は find でなく fd。
- `jq` — JSON 処理
- `yq` — YAML/TOML 処理
- `sd` — 文字列置換（sed 代替）。文字列置換は sed でなく sd を第一候補にする（-i の GNU/BSD 差異事故を避ける）。
- `tree` — 構造把握
- `git` — バージョン管理
- `gh` — GitHub 操作（--json 出力）。PR・Issue 操作は gh（--json 出力で機械可読）。
- `just` — タスクランナー。タスクは just 経由で実行する（just test / just lint）。
- `curl` — HTTP
- `shellcheck` — シェル lint
- `shfmt` — シェル整形
- `coreutils（ls / cat -n 等）` — 基本コマンド統一（BSD 差異排除）
- `sed` — GNU sed
- `awk` — GNU awk
- `unzip` — 展開
- `zstd` — 圧縮
- `sqlite3` — hive のデータ確認・デバッグ
- `python3` — a-c-m 実行・Python 層（3.11）
- `uv` — wheel 依存管理

### 追加ツール（Tier 2・standard 以上）

- `ast-grep` — 構文木ベース検索・書換。テキスト置換より安全な構文木ベースの検索・書換に用いる。
- `watchexec` — ファイル監視実行
- `delta` — diff 表示（人間レビュー用）
- `hyperfine` — ベンチマーク
- `tokei` — コード統計
- `jc` — コマンド出力の JSON 化
- `nixfmt` — Nix フォーマッタ
- `statix` — Nix lint
- `nil` — Nix LSP
- `typos` — スペルチェック
