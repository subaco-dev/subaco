{
  # standard テンプレート — minimal に agent-context-maintainer / CI / DeepWiki MCP を加えた構成。
  # Tier 1 + Tier 2。
  # 配置非依存ラッパー agent-context を devShell に載せる。
  # 注: メモリプレーンのヘルパー hive-team は multi-agent 専用。standard は
  #     文脈プレーン + 知識プレーンまでのため同梱しない（standard の .envrc も .hive を初期化しない）。
  # 自己完結（nixpkgs 直接参照・forAllSystems）。
  description = "agent-native product template (standard)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ]
          (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          # ツールの単一情報源。
          tools = import ./agent-tools.nix { inherit pkgs; };

          # --- 配置非依存ラッパー ---

          # agent-context: vendored a-c-m への配置非依存エントリ。実体解決は wrappers/agent-context.sh。
          agent-context = pkgs.writeShellApplication {
            name = "agent-context";
            runtimeInputs = [ pkgs.python311 ];
            text = builtins.readFile ./wrappers/agent-context.sh;
          };
        in
        {
          default = pkgs.mkShell {
            packages = tools.tier1 ++ tools.tier2 ++ [ agent-context ];

            # bootstrap 未実行ガード + uv sync 冪等実行 + agent-context 軽量チェック。
            shellHook = ''
              # bootstrap 未実行（uv.lock / .agents/ 不在）なら誘導のみ表示して以降をスキップ
              # （初回 direnv allow は bootstrap.sh より先に走るため、誤った修復行動を促さない）。
              if [ ! -f uv.lock ] || [ ! -d .agents ]; then
                echo "ℹ 初回セットアップが未完了です: bash ./bootstrap.sh を実行してください"
              else
                # プロダクト側 Python 依存を uv で固定・同期し、.venv を PATH 先頭に通す。
                uv sync --frozen || echo "⚠ uv sync 失敗: uv.lock と pyproject.toml を確認してください"
                export VIRTUAL_ENV="$PWD/.venv"
                export PATH="$PWD/.venv/bin:$PATH"
                # エージェント文脈ファイルの整合チェック（軽量・構造検査。生成一致は CI が検査する）。
                # check に --quiet オプションは無い（v0.1.1）。成功時の 1 行出力だけ捨て、
                # 失敗時は詳細確認と再生成の具体コマンドを案内する。
                if ! agent-context check . >/dev/null 2>&1; then
                  echo "⚠ agent context の整合が崩れています: 'agent-context check .' で詳細を確認し、"
                  echo "  'agent-context scaffold . --agent generic --append-generated-block' で再生成してください"
                fi
              fi
            '';
          };
        }
      );
    };
}
