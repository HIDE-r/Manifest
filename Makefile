include ./ScriptTools/Utils/Makefiles/rules.mk

default: help

DAILY_UPDATE_ACTION+=repo_sync
DAILY_UPDATE_ACTION+=git_update_submodule_from_remote
DAILY_UPDATE_ACTION+=zinit_update
DAILY_UPDATE_ACTION+=tldr_update
ifeq ($(IS_WSL), false)
DAILY_UPDATE_ACTION+=rime_sync
endif
DAILY_UPDATE_ACTION+=pacman_update
DAILY_UPDATE_ACTION+=paru_update
DAILY_UPDATE_ACTION+=pkgfile_update
DAILY_UPDATE_ACTION+=tmux_plugin_update
DAILY_UPDATE_ACTION+=plocate_update
DAILY_UPDATE_ACTION+=pacdiff_notify
DAILY_UPDATE_ACTION+=neovim_plugin_update

DOTBOT_DIR=.dotbot
DOTBOT_BIN=bin/dotbot
DOTBOT_CONFIG=install.conf.yaml

TPM_PATH=~/.tpm

#: Configuration Install
dotbot:
	@$(CURDIR)/$(DOTBOT_DIR)/$(DOTBOT_BIN) -d $(CURDIR) -c $(DOTBOT_CONFIG)

#: Daily update
daily_update: check_passwd $(DAILY_UPDATE_ACTION)

###
### git submodule
###
git_sync_submodule:
	git submodule sync --recursive --quiet

#: Init all submodule from parent repo
git_init_submodule:git_sync_submodule
	@ $(ECHO) '\n$(_Y)===== [Submodule init] Start =====$(_N)\n'
	git submodule update --init --recursive
	@ $(ECHO) '\n$(_Y)===== [Submodule init] End =====$(_N)\n'

#: Update all submodule from remote
git_update_submodule_from_remote:git_sync_submodule
	@ $(ECHO) '\n$(_Y)===== [Submodule update] Start =====$(_N)\n'
	cd ./DotFiles && git submodule update --remote
	@ $(ECHO) '\n$(_Y)===== [Submodule update] End =====$(_N)\n'

#: Update all submodule
git_update_submodule:git_sync_submodule
	@ $(ECHO) '\n$(_Y)===== [Submodule update] Start =====$(_N)\n'
	git submodule update --recursive
	@ $(ECHO) '\n$(_Y)===== [Submodule update] End =====$(_N)\n'

repo_sync:
	@ $(ECHO) '\n$(_Y)===== [Repo update] Start =====$(_N)\n'
	repo sync
	@ $(ECHO) '\n$(_Y)===== [Repo update] End =====$(_N)\n'

###
### git-crypt
###
#: Export git-crypt key
git-crypt_export_key:
	git-crypt export-key git-crypt.key

#: Unlock git-crypt encryption
git-crypt_unlock:
	git-crypt unlock git-crypt.key

###
### bitwarden
###

root_passwd:
	$(eval export BW_SESSION:=$(shell bw unlock | sed -n '/BW_SESSION=/{p;q}' | cut -d '"' -f2))
	@ echo $$(bw get password "ArchLinux-R9000K-root") | md5sum > root_passwd

check_passwd: root_passwd
	$(eval export INPUT_PASSWD:=$(shell read -s -p "Enter the root password:" input_passwd && echo $${input_passwd} ))
	@ echo
	@ input_hash=$$(echo ${INPUT_PASSWD} | md5sum | awk '{print $$1}'); \
	file_hash=$$(cat root_passwd | awk '{print $$1}'); \
	if [ "$$input_hash" != "$$file_hash" ]; then \
		echo "Password does not match."; \
		exit 1; \
	fi
	$(eval export ROOT_PASSWD:=$(INPUT_PASSWD))

###
### ArchLinux Package Manager
###
pkgfile_update: check_passwd
	@ $(ECHO) '\n$(_Y)===== [Pkgfile update] Start =====$(_N)\n'
	@ expect -c 'spawn sudo pkgfile -u; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'
	@ $(ECHO) '\n$(_Y)===== [Pkgfile update] End =====$(_N)\n'

pacman_update: check_passwd 
	@ $(ECHO) '\n$(_Y)===== [Pacman system update] Start =====$(_N)\n'
	@ expect -c 'spawn sudo pacman -Syu --noconfirm; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'
	@ $(ECHO) '\n$(_Y)===== [Pacman system update] End =====$(_N)\n'

paru_update: check_passwd
	@ $(ECHO) '\n$(_Y)===== [paru system update] Start =====$(_N)\n'
	@ expect -c 'spawn paru -Syu --noconfirm; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'
	@ $(ECHO) '\n$(_Y)===== [paru system update] End =====$(_N)\n'

pacdiff_notify:
	@ $(ECHO) '\n$(_Y)===== [pacdiff] Start =====$(_N)\n'
	@ pacdiff -p -o
	@ $(ECHO) '\n$(_Y)===== [pacdiff] End =====$(_N)\n'

###
### miscellaneous
###

zinit_update:
	@ $(ECHO) '\n$(_Y)===== [Zinit update] Start =====$(_N)\n'
	zsh -ic 'zinit update'
	@ $(ECHO) '\n$(_Y)===== [Zinit update] End =====$(_N)\n'

tldr_update:
	tldr -u

neovim_plugin_update:
	@ $(ECHO) '\n$(_Y)===== [$@] Start =====$(_N)\n'
	nvim -i NONE -V1 --headless -c 'lua require("lazy").sync({wait=true,show=false})' +qa
	@ $(ECHO) '\n$(_Y)===== [$@] End =====$(_N)\n'

tmux_plugin_update:
	@ $(ECHO) '\n$(_Y)===== [$@] Start =====$(_N)\n'
	$(TPM_PATH)/bin/update_plugins all
	@ $(ECHO) '\n$(_Y)===== [$@] End =====$(_N)\n'

rime_sync:
	@ $(ECHO) '\n$(_Y)===== [$@] Start =====$(_N)\n'
	~/ScriptTools/Rime/sync_fcitx5.sh
	@ $(ECHO) '\n$(_Y)===== [$@] End =====$(_N)\n'

#: update plocate database
plocate_update: check_passwd
	@ $(ECHO) '\n$(_Y)===== [$@] Start =====$(_N)\n'
	@ expect -c 'spawn sudo updatedb; expect "*password*"; send "$(ROOT_PASSWD)\r"; interact'
	@ $(ECHO) '\n$(_Y)===== [$@] End =====$(_N)\n'



.PHONY: daily_update
