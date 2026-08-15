# Subaco

**AI エージェント・ネイティブ開発環境ボイラープレートエンジン** — Nix flake テンプレート集。

Subaco は、マルチベンダーのコーディングエージェント（Claude Code / Codex / Gemini CLI / Copilot /
人間）が同じリポジトリで協業するための土台を、`nix flake init` 一発で用意します。環境（Nix + direnv）・
文脈（agent-context-maintainer）・メモリ（hive-mcp）・知識（DeepWiki MCP）・実行（cube-shim）の
各プレーンを宣言的に固定します。

- ライセンス: Apache-2.0
- GitHub: `github:ponponusa/subaco`

## 前提条件（テンプレートの外側）

次の 2 つだけは事前にホストへインストールしておいてください（それ以外のツールは flake が固定します）:

1. **Determinate Nix**（flakes / nix-command が既定で有効）— <https://determinate.systems/nix>
2. **direnv**（nix-direnv 設定済み）— <https://direnv.net>

## クイックスタート

```sh
# 1) テンプレートを展開（standard 例。安定タグ参照を推奨 — 下記「バージョン」）
nix flake init -t github:ponponusa/subaco#standard

# 2) devShell を有効化（初回は nixpkgs 取得で数分。以降は即時）
direnv allow

# 3) 初期化（プロジェクト名置換 → uv lock → git init → agent-context scaffold）
bash ./bootstrap.sh
```

`direnv allow` で devShell に入ると、`rg` / `fd` / `jq` / `just` などのツールが PATH に載ります。
`bootstrap.sh` は一度だけ、**bash 経由で**実行します（`nix flake init` はファイルの実行ビットを
保存しないため `./bootstrap.sh` は Permission denied になります。`--ci` で非対話。`-h` でヘルプ）。

> **DoD:** Determinate Nix / direnv 導入済み・キャッシュ無しのマシンで、`nix flake init -t` から
> devShell プロンプト表示と `rg --version` 応答まで 5 分以内（100Mbps 以上・cache.nixos.org 有効）。

## テンプレートの選択指針

| テンプレート | 含むもの | 使いどころ |
|---|---|---|
| `minimal` | devShell（Tier 1 ツール）+ direnv のみ | 単独ツール・単独リポジトリ。`.mcp.json` なし。agent-context-maintainer もスキップしたいケース |
| `standard` | minimal + agent-context-maintainer（`.agents/`・CI）+ DeepWiki MCP | **既定・多くのプロジェクトの出発点**（`templates.default`）。単一〜少数エージェント |
| `multi-agent` | standard + hive-mcp（メモリ）+ cube-shim（実行）+ Stop hook / 権限雛形 | 複数エージェントの協業（メッセージ・長期記憶・未信頼コードの隔離実行） |

> **multi-agent の現状（v0 の範囲）:** テンプレートの配線（`.mcp.json` / `.envrc` / devShell ラッパー
> `hive-mcp` `cube-shim`・Stop hook・オプトイン導線）は用意済みですが、**メモリ基盤 `subaco-hive` と
> 実行基盤 `subaco-shim` は別リポジトリで実装中**です。両者が PyPI 公開されるまで、`hive-*` MCP ツールと
> `sandbox_run.py` はローカル dev（`SUBACO_HIVE_DEV` / `SUBACO_SHIM_DEV`）でのみ動作します。
> minimal / standard は本体機能のみで完結し、この制約はありません。

`nix flake init -t github:ponponusa/subaco#standard` の `#standard` を `#minimal` / `#multi-agent` に
変えると各テンプレートを取得できます（`#` 省略時は `default` = `standard`）。

## バージョンと nixpkgs ピン方針

- **nixpkgs は常に現行安定リリースへ追随**します（2026-07 時点で `nixos-26.05`）。NixOS のリリース
  サイクル（5 月 / 11 月）に合わせて更新します。各テンプレートは nixpkgs を直接参照し、
  `flake.lock` で完全固定されます。
- **テンプレート取得は安定タグ参照を推奨**します。`nix flake init -t github:ponponusa/subaco#standard` は
  既定ブランチ（main）を取得するため、開発中の main がクイックスタートを壊す可能性があります。安定運用では
  タグを明示してください:

  ```sh
  nix flake init -t github:ponponusa/subaco/v0.1#standard
  ```

  タグ運用と smoke test（3 テンプレート × ubuntu/macOS）の詳細は
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml)を参照してください。

## リポジトリ構成

```
subaco/
├── flake.nix                 # templates（minimal/standard/multi-agent）+ subaco 自身の devShell
├── templates/                # 各テンプレート（自己完結・nixpkgs 直接参照）
│   ├── minimal/  standard/  multi-agent/
├── scripts/
│   ├── gen-tool-list.py      # agent-tools.nix →「## 利用可能ツール」断片（.agents/tools.md）生成
│   └── vendor-acm.sh         # agent-context-maintainer 単一ファイルの vendoring（best-effort）
├── vendor/agent-context-maintainer/   # a-c-m の vendored copy 置き場（README 参照）
├── Justfile                  # fmt / lint / check
└── .github/workflows/ci.yml  # smoke test
```

## 開発（このリポジトリを編集する）

```sh
nix develop      # または direnv allow（subaco 自身の devShell: nixfmt / statix / shellcheck / just）
just check       # 全 .nix を parse、全 .py を py_compile（オフライン・依存取得なし）
just fmt         # nixfmt + shfmt
just lint        # statix + shellcheck
just gen-tools   # .agents/tools.md を agent-tools.nix から再生成
```

## 関連リポジトリ

| リポジトリ | 役割 |
|---|---|
| `subaco`（本リポジトリ） | flake テンプレート・bootstrap・devShell・知識プレーン設定 |
| `subaco-hive` | メモリ基盤 MCP サーバー（SQLite + Zvec）。別名 hive-mcp |
| `subaco-shim` | E2B API 互換のローカル実行シム（podman / Apple Container / wslc）。別名 cube-shim |
