# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

#Create or update .vimrc
vimrc_content=$(cat <<EOL
set nocompatible
set backspace=indent,eol,start
syntax on
set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
set number
set visualbell
set mouse=a
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
EOL
)

if [ ! -f "$HOME/.vimrc" ] || ! diff <(echo "$vimrc_content") "$HOME/.vimrc" > /dev/null; then
  echo "$vimrc_content" > "$HOME/.vimrc"
fi

# Create or update .tmux.conf
tmux_conf_content='set -g mouse on
set -g default-terminal "tmux-256color"
set -g default-command /usr/bin/fish'

if [ ! -f "$HOME/.tmux.conf" ] || ! diff <(echo "$tmux_conf_content") "$HOME/.tmux.conf" &> /dev/null; then
  echo "$tmux_conf_content" > "$HOME/.tmux.conf"
fi

#Load .bashrc
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
