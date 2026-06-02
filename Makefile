REPO ?= .repo/repo/repo
ECHO ?= echo -e

default: help

DAILY_UPDATE_ACTION+=repo_sync
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
	git submodule update --init --recursive

#: Update all submodule from remote
git_update_submodule_from_remote:git_sync_submodule
	git submodule update --remote

#: Update all submodule
git_update_submodule:git_sync_submodule
	git submodule update --recursive

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
	@ expect -c 'spawn sudo pkgfile -u; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'

pacman_update: check_passwd 
	@ expect -c 'spawn sudo pacman -Syu --noconfirm; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'

paru_update: check_passwd
	@ expect -c 'spawn paru -Syu --noconfirm; expect "password*"; send "$(ROOT_PASSWD)\r"; interact'

pacdiff_notify:
	@ pacdiff -p -o

###
### miscellaneous
###

zinit_update:
	zsh -ic 'zinit update'

tldr_update:
	tldr -u

neovim_plugin_update:
	nvim -i NONE -V1 --headless -c 'lua require("lazy").sync({wait=true,show=false})' +qa
	nvim -i NONE -V1 --headless -c 'MasonUpdate' +qa

tmux_plugin_update:
	$(TPM_PATH)/bin/update_plugins all

rime_sync:
	./ScriptTools/Rime/sync_fcitx5.sh

#: update plocate database
plocate_update: check_passwd
	@ expect -c 'spawn sudo updatedb; expect "*password*"; send "$(ROOT_PASSWD)\r"; interact'


#: sync repo to init state
repo_init:
	$(REPO) sync
	$(REPO) forall -c 'git submodule update --init --recursive'
	$(REPO) start local --all

#: sync repo from remote
repo_sync:
	$(REPO) sync
	$(REPO) forall -c 'git submodule update --remote'

#: checkout repo status
repo_status:
	$(REPO) status

#: push all commit to remote
repo_push:
	$(REPO) forall -i '.dotbot' -c 'status=$$(git status -sb); echo "===== $$REPO_PATH ====="; echo "$$status"; echo "$$status" | grep -q "ahead" && git push origin HEAD:main || true'

help:
	remake --tasks

.PHONY: daily_update
