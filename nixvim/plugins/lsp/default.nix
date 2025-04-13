{
  lib,
  config,
  ...
}: {
  options = {
    lsp.enable = lib.mkEnableOption "Enable lsp nixvim plugins module";
  };
  config = lib.mkIf config.lsp.enable {
    programs.nixvim.plugins = {
      lsp-format = {
        enable = true;
        lspServersToEnable = [
          "gopls"
          "nixd"
        ];
      };
      lsp = {
        enable = true;
        #capabilities = ''
        #capabilities = require('blink.cmp').get_lsp_capabilities()
        #'';
        keymaps = {
          silent = true;
          diagnostic = {
            # Navigate in diagnostics
            "<leader>k" = "goto_prev";
            "<leader>j" = "goto_next";
          };
          lspBuf = {
            gd = "definition";
            gD = "references";
            gt = "type_definition";
            gi = "implementation";
            K = "hover";
            grn = "rename";
          };
        };
        servers = {
          gopls = {
            enable = true;
            settings.formatting.command = "gofmt";
          };
          lua_ls.enable = true;
          gleam.enable = true;
          marksman.enable = false;
          markdown_oxide = {
            enable = true;
            filetypes = [
              "markdown"
              "md"
            ];
          };
          tflint.enable = true;
          nixd = {
            enable = true;
            settings.formatting.command = ["alejandra"];
          };
          ts_ls.enable = true;
          elixirls = {
            enable = true;
          };
          rust_analyzer = {
            enable = true;
            installRustc = false;
            installCargo = false;
          };
          terraform_lsp.enable = true;
        };
      };
    };
  };
}
