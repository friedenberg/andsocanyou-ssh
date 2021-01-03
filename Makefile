
SHELL = /bin/sh
export SHELL

DIR_BUILD := build
DIR_GNUPG_FILES := gnupg_files
GNUPG_FILES := $(wildcard $(DIR_GNUPG_FILES)/*)
GNUPG_FILES_SCRIPTS := $(patsubst $(DIR_GNUPG_FILES)/%,build/%,$(GNUPG_FILES))

FILE_OUTPUT := $(DIR_BUILD)/bootstrap

CMD_BREW := brew bundle exec --

all: $(FILE_OUTPUT)

$(FILE_OUTPUT): build/configure $(GNUPG_FILES_SCRIPTS) | build/
	-rm $(FILE_OUTPUT)

	cat \
		build/configure \
		$(GNUPG_FILES_SCRIPTS) >> $(FILE_OUTPUT)

	$(CMD_BREW) shfmt -w $(FILE_OUTPUT)

	chmod +x $(FILE_OUTPUT)

build/configure: files/Brewfile | build
	-rm build/configure
	echo "#! /bin/sh" >> build/configure
	echo "" >> build/configure
	echo '/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"' >> build/configure
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
lint: $(FILE_OUTPUT)
	$(CMD_BREW) shellcheck $(FILE_OUTPUT)

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

.PHONY: bump_version
bump_version:
	"$${EDITOR:-$${VISUAL:-vi}}" ./VERSION
	git add ./VERSION
	@git diff --exit-code -s ./VERSION || (echo "version wasn't changed" && exit 1)
	git commit -m "bumped version to $$(cat ./VERSION)"
	git push origin master

.PHONY: release
release: fail_if_stage_dirty $(FILE_OUTPUT) bump_version
	$(CMD_BREW) hub release create \
		-a $(FILE_OUTPUT) \
		-m "v$$(cat ./VERSION)" \
		"v$$(cat ./VERSION)"

.PHONY: fail_if_stage_dirty
fail_if_stage_dirty:
	@git diff --exit-code -s || (echo "unstaged changes, refusing to release" && exit 1)


