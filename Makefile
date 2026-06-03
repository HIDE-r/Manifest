REPO ?= .repo/repo/repo
ECHO ?= echo -e
SUDO ?= sudo
SUDO_N ?= $(SUDO) -n

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
DAILY_UPDATE_ACTION+=neovim_plugin_update

DOTBOT_DIR=.dotbot
DOTBOT_BIN=bin/dotbot
DOTBOT_CONFIG=install.conf.yaml

TPM_PATH=~/.tpm

sudo_validate:
	$(SUDO) -v

#: Configuration Install
dotbot:
	@$(CURDIR)/$(DOTBOT_DIR)/$(DOTBOT_BIN) -d $(CURDIR) -c $(DOTBOT_CONFIG)

#: Daily update
daily_update: sudo_validate
	@./Manifest/scripts/daily_update.sh $(DAILY_UPDATE_ACTION)

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
### ArchLinux Package Manager
###
pkgfile_update: sudo_validate
	@$(SUDO_N) pkgfile -u

pacman_update: sudo_validate
	@$(SUDO_N) pacman -Syu --noconfirm

paru_update: sudo_validate
	@paru -Sua --noconfirm --sudoloop

pacdiff_notify:
	@ output=$$(pacdiff -p -o); \
	if [ -n "$$output" ]; then \
		printf '%s\n' "$$output"; \
		printf '__DAILY_UPDATE_STATUS=warn:pacdiff has files that need review\n'; \
	fi

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
plocate_update: sudo_validate
	@$(SUDO_N) updatedb


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
	@awk 'BEGIN {FS = ":.*"; desc = ""} /^#: / {desc = substr($$0, 4); next} /^[[:alnum:]_.-]+:/ {if (desc != "") {printf "  %-34s %s\n", $$1, desc; desc = ""}}' $(MAKEFILE_LIST)

.PHONY: daily_update help
