
SHELL = /bin/sh
export SHELL

DIR_BUILD := build
DIR_GNUPG_FILES := gnupg_files
GNUPG_FILES := $(wildcard $(DIR_GNUPG_FILES)/*)
GNUPG_FILES_SCRIPTS := $(patsubst $(DIR_GNUPG_FILES)/%,build/%,$(GNUPG_FILES))

all: build/bootstrap

build/bootstrap: build/configure $(GNUPG_FILES_SCRIPTS) | build/
	-rm build/bootstrap

	cat \
		build/configure \
		$(GNUPG_FILES_SCRIPTS) >> build/bootstrap

	brew bundle exec -- shfmt -w build/bootstrap

	chmod +x build/bootstrap

build/configure: files/Brewfile | build
	-rm build/configure
	echo "#! /bin/sh" >> build/configure
	echo "" >> build/configure
	echo '/usr/bin/ruby -e "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"' >> build/configure
	echo "cat << EOF | brew bundle install --file=-" >> build/configure
	cat files/Brewfile >> build/configure
	echo "EOF" >> build/configure
	chmod +x build/configure

$(GNUPG_FILES_SCRIPTS): $(GNUPG_FILES)
	echo "#! /bin/sh" >> build/$(notdir $@)
	echo "" >> build/$(notdir $@)
	echo "cat << EOF >> ~/.gnupg/$(notdir $@)" >> build/$(notdir $@)
	cat $(DIR_GNUPG_FILES)/$(notdir $@) >> build/$(notdir $@)
	echo "EOF" >> build/$(notdir $@)
	chmod +x build/$(notdir $@)

build/:
	mkdir build/

.PHONY: lint
lint: build/bootstrap
	brew bundle exec -- shellcheck build/bootstrap

.PHONY: test_gnupg_files
test_gnupg_files:
	gpgconf --kill gpg-agent
	-rm -r ~/.gnupg/
	mkdir ~/.gnupg/
	cp -r $(DIR_GNUPG_FILES)/ ~/.gnupg/
	gpg-connect-agent /bye
	env SSH_AUTH_SOCK=$$(gpgconf --list-dirs agent-ssh-socket) ssh -T git@github.com || true

.PHONY: clean
clean:
	-rm -r $(DIR_BUILD)

.PHONY: install_deps
install_deps:
	brew install git
	brew install hub

.PHONY: bump_version
bump_version:
	"$${EDITOR:-$${VISUAL:-vi}}" ./VERSION
	git add ./VERSION
	@git diff --exit-code -s ./VERSION || (echo "version wasn't changed" && exit 1)
	git commit -m "bumped version to $$(cat ./VERSION)"
	git push origin master

.PHONY: release
release: fail_if_stage_dirty $(DIR_BUILD)/bootstrap bump_version
	hub release create \
		-a $(DIR_BUILD)/bootstrap \
		-m "v$$(cat ./VERSION)" \
		"v$$(cat ./VERSION)"

.PHONY: fail_if_stage_dirty
fail_if_stage_dirty:
	@git diff --exit-code -s || (echo "unstaged changes, refusing to release" && exit 1)


