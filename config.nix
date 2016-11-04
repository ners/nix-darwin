{ pkgs ? import <nixpkgs> {} }:

let

  eval = pkgs.lib.evalModules
    { check = true;
      args = { pkgs = import <nixpkgs> {}; };
      modules =
        [ config
          ./modules/system.nix
          ./modules/environment.nix
          ./modules/launchd
          ./modules/tmux.nix
          <nixpkgs/nixos/modules/system/etc/etc.nix>
        ];
    };

  config =
    { config, lib, pkgs, ... }:
    {
      environment.systemPackages =
        [ pkgs.lnl.vim
          pkgs.curl
          pkgs.fzf
          pkgs.gettext
          pkgs.git
          pkgs.jq
          pkgs.silver-searcher
          pkgs.tmux

          pkgs.nix-repl
          pkgs.nox
        ];

      launchd.daemons.nix-daemon =
        { serviceConfig.Program = "${pkgs.nix}/bin/nix-daemon";
          serviceConfig.KeepAlive = true;
          serviceConfig.RunAtLoad = true;
          serviceConfig.EnvironmentVariables.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          serviceConfig.EnvironmentVariables.TMPDIR = "/nix/tmp";
          serviceConfig.SoftResourceLimits.NumberOfFiles = 4096;
          serviceConfig.ProcessType = "Background";
        };

      programs.tmux.loginShell = "${pkgs.zsh}/bin/zsh -l";
      programs.tmux.enableSensible = true;
      programs.tmux.enableMouse = true;
      programs.tmux.enableVim = true;

      environment.variables.EDITOR = "vim";
      environment.variables.HOMEBREW_CASK_OPTS = "--appdir=/Applications/cask";

      environment.variables.GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      environment.variables.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

      environment.shellAliases.l = "ls -lh";
      environment.shellAliases.ls = "ls -G";
      environment.shellAliases.tmux = "${pkgs.tmux}/bin/tmux -f ${config.environment.etc."tmux.conf".source}";
      environment.shellAliases.zsh = "${pkgs.zsh}/bin/zsh";

      environment.etc."tmux.conf".text = ''
        ${config.programs.tmux.config}
        bind 0 set status

        set -g status-bg black
        set -g status-fg white

        source-file $HOME/.tmux.conf.local
      '';

      environment.etc."profile".text = ''
        source ${config.system.build.setEnvironment}
        source ${config.system.build.setAliases}

        conf=$HOME/src/nixpkgs-config
        pkgs=$HOME/.nix-defexpr/nixpkgs

        source $HOME/.profile.local
      '';

      environment.etc."zshenv".text = ''
        autoload -U compinit && compinit
        autoload -U promptinit && promptinit

        bindkey -e
        setopt autocd
        setopt inc_append_history
        setopt share_history

        HISTFILE=$HOME/.zhistory
        HISTSIZE=4096
        SAVEHIST=$HISTSIZE
        PROMPT='%B%(?..%? )%b⇒ '
        RPROMPT='%F{green}%~%f'

        source $HOME/.zshenv.local
      '';

      environment.etc."zshrc".text = ''
        export PATH=/var/run/current-system/sw/bin:/var/run/current-system/sw/bin''${PATH:+:$PATH}
        export PATH=/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin''${PATH:+:$PATH}
        export PATH=$HOME/.nix-profile/bin:$HOME/.nix-profile/bin''${PATH:+:$PATH}

        export NIX_PATH=nixpkgs=$HOME/.nix-defexpr/nixpkgs

        typeset -U NIX_PATH
        typeset -U PATH

        # Set up secure multi-user builds: non-root users build through the
        # Nix daemon.
        if [ "$USER" != root -a ! -w /nix/var/nix/db ]; then
            export NIX_REMOTE=daemon
        fi

        nixdarwin-rebuild () {
            case $1 in
                'build')  nix-build --no-out-link '<nixpkgs>' -A nixdarwin.toplevel ;;
                'repl')   nix-repl "$HOME/.nixpkgs/config.nix" ;;
                'shell')  nix-shell '<nixpkgs>' -p nixdarwin.toplevel --run "${pkgs.zsh}/bin/zsh -l" ;;
                'switch') nix-env -f '<nixpkgs>' -iA nixdarwin.toplevel && nix-shell '<nixpkgs>' -A nixdarwin.toplevel --run 'sudo $out/activate'  && exec ${pkgs.zsh}/bin/zsh -l ;;
                "")       return 1 ;;
            esac
        }

        source $HOME/.zshrc.local
      '';
    };


in {
  inherit eval;

  packageOverrides = self: {

    nixdarwin = eval.config.system.build;

    lnl.vim = pkgs.vim_configurable.customize {
      name = "vim";
      vimrcConfig.customRC = ''
        set nocompatible
        filetype plugin indent on
        syntax on

        colorscheme solarized
        set bg=dark

        set et sw=2 ts=2
        set bs=indent,start

        set nowrap
        set list
        set listchars=tab:»·,trail:·,extends:⟩,precedes:⟨
        set fillchars+=vert:\ ,stl:\ ,stlnc:\ 

        set lazyredraw

        set clipboard=unnamed

        cmap <C-g> <Esc>
        imap <C-g> <Esc>
        nmap <C-g> <Esc>
        omap <C-g> <Esc>
        vmap <C-g> <Esc>

        vmap s S

        cnoremap %% <C-r>=expand('%:h') . '/'<CR>

        set hlsearch
        nnoremap // :nohlsearch<CR>

        let mapleader = ' '
        nnoremap <Leader>p :FZF<CR>
        nnoremap <silent> <Leader>e :exe 'FZF ' . expand('%:h')<CR>

        source $HOME/.vimrc.local
      '';
      vimrcConfig.vam.knownPlugins = with pkgs.vimUtils; (pkgs.vimPlugins // {
        vim-nix = buildVimPluginFrom2Nix {
          name = "vim-nix-unstable";
          src = ../vim-nix;
        };
      });
      vimrcConfig.vam.pluginDictionaries = [
        { names = [ "fzfWrapper" "youcompleteme" "fugitive" "surround" "vim-nix" "colors-solarized" ]; }
      ];
    };

  };
}