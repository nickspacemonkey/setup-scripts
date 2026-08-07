set fish_greeting
fish_vi_key_bindings

fish_add_path --path $HOME/.local/bin

if type -q exa
    alias ll 'exa -lga'
else if type -q eza
    alias ll 'eza -lga'
else
    alias ll 'ls -la'
end

if type -q nala
    alias apt nala
end

if type -q bat
    alias cat 'bat -pp'
    alias less 'bat -p'
else if type -q batcat
    alias cat 'batcat -pp'
    alias less 'batcat -p'
end

if type -q hx
    alias vi hx
    alias vim hx
else if type -q helix
    alias vi helix
    alias vim helix
end

alias myip 'curl ifconfig.io'

abbr grep 'grep --color=auto'
abbr df 'df -hT'
abbr du 'du -h'
abbr mkdir 'mkdir -p'

# Tmux aliases
alias t 'tmux attach || tmux new-session'
alias ta 'tmux attach -t'
alias tn 'tmux new-session'
alias tl 'tmux list-sessions'

# Docker aliases
alias dc 'sudo docker compose'
alias dcup 'sudo docker compose up --force-recreate -d'
alias dcdown 'sudo docker compose down'
alias dcrestart 'sudo docker compose restart'
alias docker-clean 'sudo docker container prune -f; and \
                    sudo docker image prune -af; and \
                    sudo docker network prune -f; and \
                    sudo docker volume prune -af'

# Use .. ... .... to move up directories
function multicd
    echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
end
abbr --add dotdot --regex '^\.\.+$' --function multicd

# sudo alias fix
function sudo --description "Fixes expanding aliases for sudo"
    if functions -q -- "$argv[1]"
        set cmdline (
            for arg in $argv
                printf "\"%s\" " $arg
            end
        )
        set -x function_src (string join "\n" (string escape --style=var (functions "$argv[1]")))
        set argv fish -c 'string unescape --style=var (string split "\n" $function_src) | source; '$cmdline
        command sudo -E $argv
    else
        command sudo $argv
    end
end

# Bash Style Command Substitution and Chaining (!! !$)
function last_history_item
    echo $history[1]
end
abbr -a !! --position anywhere --function last_history_item

# Abbreviation for running updates
function update
    if type -q /usr/bin/update
        sudo bash update
    else if type -q nala
        sudo nala upgrade
    else if type -q apt
        sudo apt update && sudo apt upgrade
    else if type -q dnf
        sudo dnf upgrade
    else if type -q nix
        sudo nixos-rebuild switch --upgrade
    else
        echo "Neither apt nor dnf is installed."
    end
end

# Set full paths
set -U fish_prompt_pwd_dir_length 0

# White text for valid input
set -U fish_color_command white

if status is-interactive; and not set -q TMUX; and set -q SSH_CONNECTION
    tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux
end
