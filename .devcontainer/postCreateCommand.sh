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
# ~/.config/gh is a named volume; Docker creates its mount point owned by root.
sudo chown -R "$(whoami)" "${HOME}/.config/gh"
gh config set editor 'zed --wait'
# Let git use the gh login for GitHub (what gh auth setup-git writes, without
# requiring a login first), so a new clone works without extra setup.
for host in github.com gist.github.com; do
	git config --global "credential.https://${host}.helper" ''
	git config --global --add "credential.https://${host}.helper" '!gh auth git-credential'
done
if gh auth status > /dev/null 2>&1; then
	gh extension install github/gh-stack --force
	gh skill install github/gh-stack gh-stack --agent claude-code --scope project --force
else
	echo 'Skipped installing the gh stack extension and skill: GitHub CLI is not logged in.'
	echo 'Log in with "gh auth login --with-token < <token file>", then run:'
	echo '  gh extension install github/gh-stack --force'
	echo '  gh skill install github/gh-stack gh-stack --agent claude-code --scope project --force'
fi

echo 'Setting up Lefthook...'
bin/bundle exec lefthook install

echo 'Setting up Ruby LSP...'
gem install ruby-lsp --no-document
