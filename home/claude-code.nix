{ pkgs, ... }:

let
  ccstatusline = pkgs.callPackage ../pkgs/ccstatusline.nix { };
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code; # 모듈이 바이너리 소유 (configuration.nix 에서는 제거)

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
        DISABLE_AUTOUPDATER = "1"; # nix 가 바이너리 소유 → 자동 업데이트 끔
        ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8[1m]";
        CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6";
        CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "50";
        ENABLE_PROMPT_CACHING_1H = "1";
        BASH_MAX_OUTPUT_LENGTH = "10000";
        MAX_MCP_OUTPUT_TOKENS = "10000";
        # 스크롤 fix: fullscreen(alternate screen) 대신 네이티브 터미널 스크롤백 사용
        CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN = "1";
        CLAUDE_CODE_DISABLE_MOUSE = "1";
      };

      statusLine = {
        type = "command";
        command = "${ccstatusline}/bin/ccstatusline";
        padding = 0;
      };
    };

    # rules/agents/commands/hooks/skills 는 넣을 콘텐츠가 생기면 rulesDir 등으로 추가.
    # (존재하지 않는 디렉터리를 가리키면 빌드 실패하므로 지금은 미설정)
  };
}
