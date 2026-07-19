{ pkgs, ... }:

let
  # 스크립트를 store 에 넣고 의존성을 래퍼 PATH 로 번들 (self-contained)
  mkScriptBin = name: script: deps:
    pkgs.runCommandLocal name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      install -Dm755 ${script} $out/bin/${name}
      wrapProgram $out/bin/${name} \
        --prefix PATH : ${pkgs.lib.makeBinPath deps}
    '';

  statusline = mkScriptBin "claude-statusline" ./statusline.sh
    (with pkgs; [ bash coreutils gnugrep gawk bc jq git ]);

  # hook 스크립트 (settings.hooks 에서 store 경로로 참조)
  nixFmtHook = mkScriptBin "claude-hook-nix-fmt" ./hooks/nix-fmt.sh
    (with pkgs; [ bash coreutils jq nixpkgs-fmt ]);
  reproCheckHook = mkScriptBin "claude-hook-repro-check" ./hooks/repro-check.sh
    (with pkgs; [ bash coreutils gnugrep git ]);
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # MCP 서버 (선언형). 바이너리를 store 경로로 직접 참조 → PATH·런타임 다운로드 의존 없음.
    mcpServers = {
      nixos = {
        type = "stdio";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
      fetch = {
        type = "stdio";
        command = "${pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
      };
    };

    # skill (선언형). nix 변경 시 재현성·컨벤션·README 문서화를 점검하는 playbook.
    skills.nix-change-review = ./skills/nix-change-review.md;

    settings = {
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(sudo nixos-rebuild*)"
          "Bash(nix *)"
          "Bash(nix-*)"
          "Bash(nixos-option*)"
          "Bash(sudo nix*)"
          "Bash(git *)"
          "Bash(systemctl status*)"
          "Bash(systemctl list-units*)"
          "Bash(journalctl*)"
          "Bash(ls *)"
          "Bash(find *)"
          "Bash(grep *)"
          "Bash(df *)"
          "Bash(free *)"
          "Bash(ip *)"
          "Bash(ss *)"
          "Bash(ps *)"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.env.*)"
          "Read(./secrets/**)"
        ];
      };

      theme = "dark";
      model = "opus";
      effortLevel = "high";
      advisorModel = "opus";

      skipAutoPermissionPrompt = true;
      skipDangerousModePermissionPrompt = true;
      skipWorkflowUsageWarning = true;

      env = {
        DISABLE_AUTOUPDATER = "1";
        ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8[1m]";
        CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
        ENABLE_PROMPT_CACHING_1H = "1";
        BASH_MAX_OUTPUT_LENGTH = "10000";
        MAX_MCP_OUTPUT_TOKENS = "10000";
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        CLAUDE_CODE_DISABLE_MOUSE = "1";
      };

      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
        padding = 0;
        refreshInterval = 10;
      };

      # hook (선언형, 기계적 강제)
      hooks = {
        # .nix 편집 후 자동 포맷
        PostToolUse = [
          {
            matcher = "Edit|Write|MultiEdit";
            hooks = [
              { type = "command"; command = "${nixFmtHook}/bin/claude-hook-nix-fmt"; }
            ];
          }
        ];
        # 종료 시 재현 불가 "냄새" 탐지 → 경고(비차단)
        Stop = [
          {
            hooks = [
              { type = "command"; command = "${reproCheckHook}/bin/claude-hook-repro-check"; }
            ];
          }
        ];
      };
    };
  };
}
