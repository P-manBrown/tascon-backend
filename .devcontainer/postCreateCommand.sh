#!/usr/bin/env bash
set -eu

echo 'Setting up Shell...'
cat <<-'EOF' | tee -a "${HOME}/.bashrc" >> "${HOME}/.zshrc"
	precmd() {
	  last_cmd="$(history | tail -1 | sed -r 's/\s+[0-9]+\s+//')"
	  if [[ "${last_cmd}" =~ ^(bin/)?bundle(\\s+((install|-+).*$)|$) ]]; then
	    echo 'Running `yard gems` to generate docs for gems...'
	    for _ in {1..3}; do
	      yard gems -quiet && break
	    done
	  fi
	}
	SHELL="$(readlink "/proc/$$/exe")"
	export HISTFILE="${HOME}/shell_log/.${SHELL##*/}_history"
	if [[ ${SHLVL} -eq 2 ]]; then
	  mkdir -p "${HOME}/shell_log/${SHELL##*/}"
	  create_date="$(date '+%Y%m%d%H%M%S')"
	  script -f "${HOME}/shell_log/${SHELL##*/}/${create_date}.log"
	fi
EOF
echo "export PROMPT_COMMAND='history -a && precmd'" >> "${HOME}/.bashrc"
git clone \
	https://github.com/zsh-users/zsh-autosuggestions \
	"${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
oh_my_plugins="(bundler gh git rails zsh-autosuggestions)"
sed -i "s/^plugins=(.*)/plugins=${oh_my_plugins}/" "${HOME}/.zshrc"
sudo chown -R "${USER}" "${HOME}/shell_log"

echo 'Setting up Git...'
set +e
repo_root="$(git rev-parse --show-toplevel)"
set -e
sudo git config --system --add safe.directory "${repo_root:-${PWD}}"
git config --local core.editor 'code --wait'

echo 'Setting up GitHub CLI...'
gh config set editor 'code --wait'

echo 'Setting up Thunder Client...'
vscode_global_storage="${HOME}/.vscode-server/data/User/globalStorage"
mkdir -p "${vscode_global_storage}/rangav.vscode-thunder-client"

echo 'Setting up Lefthook...'
bin/bundle exec lefthook install

echo 'Setting up Solargraph...'
sed -iz 's/- require_not_found\n//' "${HOME}/.config/solargraph/config.yml"
for _ in {1..3}; do
	yard gems -quiet && break
done
