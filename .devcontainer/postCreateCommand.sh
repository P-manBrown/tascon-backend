#!/usr/bin/env bash
set -eu

echo 'Setting up Shell...'
cat <<-'EOF' | tee -a "${HOME}/.bashrc" >> "${HOME}/.zshrc"
	SHELL="$(readlink "/proc/$$/exe")"
	shell_log_dir="${HOME}/shell_log"
	export HISTFILE="${shell_log_dir}/.${SHELL##*/}_history"
	if [[ ${SHLVL} -eq 2 ]]; then
	  mkdir -p ${shell_log_dir}
	  find ${shell_log_dir} -name '*.log' -mtime +7 -delete
	  creation_date="$(date '+%Y%m%d%H%M%S')"
	  script -f "${shell_log_dir}/${creation_date}.log"
	fi
EOF
echo "export PROMPT_COMMAND='history -a && precmd'" >> "${HOME}/.bashrc"
git clone \
	https://github.com/zsh-users/zsh-autosuggestions \
	"${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
oh_my_plugins="(bundler gh git rails zsh-autosuggestions)"
sed -i "s/^plugins=(.*)/plugins=${oh_my_plugins}/" "${HOME}/.zshrc"
sudo chown -R "$(whoami)" "${HOME}/shell_log"

echo 'Setting up Git...'
set +e
repo_root="$(git rev-parse --show-toplevel)"
set -e
sudo git config --system --add safe.directory "${repo_root:-${PWD}}"
git config --local core.editor 'zed --wait'

echo 'Setting up GitHub CLI...'
gh config set editor 'zed --wait'
gh skill install github/gh-stack gh-stack --agent claude-code --scope project --force

echo 'Setting up Lefthook...'
bin/bundle exec lefthook install
