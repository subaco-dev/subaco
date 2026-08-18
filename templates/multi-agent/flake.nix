{
  # multi-agent テンプレート — standard に hive-mcp（メモリプレーン）と cube-shim（実行プレーン）を
  # 加えたフル構成。Tier 1 + Tier 2 + Tier 3。
  # 配置非依存ラッパー hive-mcp / cube-shim / agent-context / hive-team を devShell に載せる。
  # 自己完結（nixpkgs 直接参照・forAllSystems）。
  description = "agent-native product template (multi-agent)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          # ツールの単一情報源（Tier 1 / Tier 2）。
          tools = import ./agent-tools.nix { inherit pkgs; };

          # --- 配置非依存ラッパー ---

          # agent-context: vendored a-c-m への配置非依存エントリ（standard と同一実装）。
          agent-context = pkgs.writeShellApplication {
            name = "agent-context";
            runtimeInputs = [ pkgs.python311 ];
            text = builtins.readFile ./wrappers/agent-context.sh;
          };

          # hive-team: チーム名導出の単一ソース。正規化は lib/hive_team.py に唯一実装。
          hive-team = pkgs.writeShellApplication {
            name = "hive-team";
            runtimeInputs = [ pkgs.git ];
            text = ''exec ${pkgs.python311}/bin/python3 ${./lib/hive_team.py} "$@"'';
          };

          # hive-mcp: .mcp.json が呼ぶ command。uvx で subaco-hive（stdio MCP）を起動。
          hive-mcp = pkgs.writeShellApplication {
            name = "hive-mcp";
            runtimeInputs = [ pkgs.uv ];
            text = builtins.readFile ./wrappers/hive-mcp.sh;
          };

          # cube-shim: uvx で subaco-shim serve（ローカル実行シム）を起動。
          cube-shim = pkgs.writeShellApplication {
            name = "cube-shim";
            runtimeInputs = [ pkgs.uv ];
            text = builtins.readFile ./wrappers/cube-shim.sh;
          };
        in
        {
          default = pkgs.mkShell {
            packages =
              tools.tier1
              ++ tools.tier2
              # Tier 3: multi-agent 専用。
              ++ [
                agent-context
                hive-team
                hive-mcp
                cube-shim
                pkgs.openssh # リモート CubeSandbox 接続用（強隔離オプション）
              ]
              # podman は cube-shim のローカルフォールバック用。Linux のみ nixpkgs から入れる
              # （macOS Apple Silicon は Apple Container、Intel Mac はシステム podman を使う）。
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.podman ];
            # 注: e2b-code-interpreter は uv 側（pyproject / uv.lock）で管理し、devShell には入れない。

            # bootstrap 未実行ガード + uv sync 冪等実行 + agent-context 軽量チェック
            # （standard と同一。hive/cube の初期化・環境変数配線は .envrc が担う）。
            shellHook = ''
              if [ ! -f uv.lock ] || [ ! -d .agents ]; then
                echo "ℹ 初回セットアップが未完了です: bash ./bootstrap.sh を実行してください"
              else
                uv sync --frozen || echo "⚠ uv sync 失敗: uv.lock と pyproject.toml を確認してください"
                export VIRTUAL_ENV="$PWD/.venv"
                export PATH="$PWD/.venv/bin:$PATH"
                # 構造検査のみ（生成一致は CI）。check に --quiet は無い（v0.1.1）ため出力抑止で代替。
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
