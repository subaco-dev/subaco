{
  # Subaco — AIエージェント・ネイティブ開発環境ボイラープレートエンジン。
  # 本 flake は 3 種のテンプレート（minimal / standard / multi-agent）を配布し、
  # あわせて subaco リポジトリ自身を編集するための devShell を提供する。
  description = "Subaco — agent-native product boilerplate（flake templates）";

  # nixpkgs は常に現行安定リリースへ追随する（5 月／11 月リリースに合わせて更新）。
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      # サポート対象の 4 システム（forAllSystems）。
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
      # flake templates 出力。利用者は次で新規プロダクトを開始する:
      #   nix flake init -t github:subaco-dev/subaco#standard
      # 各テンプレートは templates/<name>/ 配下に自己完結する（nixpkgs 直接参照）。
      templates = {
        minimal = {
          path = ./templates/minimal;
          description = "最小: devShell + direnv のみ（単独ツール／単独リポジトリ向け。.mcp.json なし）";
        };
        standard = {
          path = ./templates/standard;
          description = "標準: minimal + agent-context + CI + DeepWiki MCP";
        };
        multi-agent = {
          path = ./templates/multi-agent;
          description = "フル: standard + hive-mcp（メモリ）+ cube-shim（実行）";
        };
        # 既定は standard（クイックスタート例に一致）。
        default = self.templates.standard;
      };

      # 共通サンドボックス OCI イメージ（設計書 §5.5 / 実装計画書 M2a-3）。
      # cube-shim の 3 ドライバ（podman / Apple Container / wslc）が pull する単一イメージで、
      # 「どの OS・どのバックエンドで実行しても環境プレーンと同じツールチェーン」を保つため、
      # multi-agent テンプレートの agent-tools.nix（tier1 + tier2）を唯一の情報源として流用する。
      # buildLayeredImage は Linux ビルドホスト上でネイティブアーキのみ生成できるため、
      # 出力は x86_64-linux / aarch64-linux に限定し、CI（.github/workflows/sandbox-image.yml）が
      # 2 アーキをビルドしてマニフェストリストとして GHCR へ push する。ドライバは
      # マニフェストリスト digest（CUBE_TEMPLATE_ID）で pull し自ホストのアーキを自動解決する。
      # macOS ローカルでビルドしたい場合の代替（linux-builder）は README を参照。
      packages =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
          ]
          (
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
              tools = import ./templates/multi-agent/agent-tools.nix { inherit pkgs; };
            in
            {
              sandbox-image = pkgs.dockerTools.buildLayeredImage {
                # GHCR の最終的な push 先と一致させる（ローカル podman load でもこの名で載る）。
                # tag は未指定＝出力ハッシュ由来（CI が push 時に vX.Y-<arch> へ retag する）。
                name = "ghcr.io/subaco-dev/subaco-sandbox";
                contents = [
                  # devShell と同一のツールチェーン（環境一致）。bash はコンテナ内シェル用。
                  (pkgs.buildEnv {
                    name = "subaco-sandbox-tools";
                    paths = tools.tier1 ++ tools.tier2 ++ [ pkgs.bashInteractive ];
                  })
                  # /bin/sh・/usr/bin/env（shim の put_file / シェバン実行が前提とする）。
                  pkgs.dockerTools.binSh
                  pkgs.dockerTools.usrBinEnv
                  # CA バンドル（既定は egress 遮断だが、オプトイン経路の TLS を壊さない）。
                  pkgs.dockerTools.caCertificates
                ];
                # /tmp（sticky）と root の HOME。buildLayeredImage は既定でどちらも作らない。
                extraCommands = ''
                  mkdir -p tmp root
                  chmod 1777 tmp
                  chmod 700 root
                '';
                config = {
                  # shim のドライバは run 時に明示コマンド（sleep infinity）を渡す
                  # （subaco-shim drivers/_commands.py）。単体 podman run でも同挙動になるよう
                  # 既定 Cmd を一致させる。
                  Cmd = [
                    "sleep"
                    "infinity"
                  ];
                  Env = [
                    "PATH=/usr/bin:/bin"
                    "HOME=/root"
                    # C ロケール由来の ASCII stdio を避ける（run_code の UTF-8 出力前提）。
                    "LANG=C.UTF-8"
                    "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                  ];
                  WorkingDir = "/root";
                  Labels = {
                    # source ラベルで GHCR パッケージをリポジトリへ自動リンクする。
                    "org.opencontainers.image.source" = "https://github.com/subaco-dev/subaco";
                    "org.opencontainers.image.description" = "Subaco 共通サンドボックスイメージ（環境プレーンと同一ツールチェーン）";
                  };
                };
              };
            }
          );

      # subaco リポジトリ自身の開発 devShell。
      # テンプレートの .nix / .sh を触るのもエージェントであるため、Nix/シェルの整備道具を揃える。
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style # Nix フォーマッタ（RFC スタイル）
            nil # Nix LSP
            statix # Nix lint
            shellcheck # シェル lint（ラッパースクリプト検査）
            shfmt # シェル整形
            just # タスクランナー
          ];
        };
      });

      # `nix fmt` 用フォーマッタ。
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
