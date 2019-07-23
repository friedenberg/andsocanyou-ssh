
SHELL = /bin/sh
export SHELL

DIR_BUILD := build
GNUPG_FILES := $(wildcard gnupg/*)
GNUPG_FILES_SCRIPTS := $(patsubst gnupg/%,build/%,$(GNUPG_FILES))

all: build/bootstrap

build/bootstrap: build/install_homebrew build/configure $(GNUPG_FILES_SCRIPTS) | build/
	-rm build/bootstrap

	cat \
		build/install_homebrew \
		build/configure \
		$(GNUPG_FILES_SCRIPTS) >> build/bootstrap

	chmod +x build/bootstrap

build/install_homebrew: | build
	cp scripts/install_homebrew build/

build/configure:
	-rm build/configure
	echo "#! /bin/sh" >> build/configure
	echo "" >> build/configure
	echo "cat << EOF | brew bundle install --file=-" >> build/configure
	cat Brewfile >> build/configure
	echo "EOF" >> build/configure
	chmod +x build/configure

$(GNUPG_FILES_SCRIPTS): $(GNUPG_FILES)
	echo "#! /bin/sh" >> build/$(notdir $@)
	echo "" >> build/$(notdir $@)
	echo "cat << EOF >> ~/.gnupg/$(notdir $@)" >> build/$(notdir $@)
	cat gnupg/$(notdir $@) >> build/$(notdir $@)
	echo "EOF" >> build/$(notdir $@)
	chmod +x build/$(notdir $@)

build/:
	mkdir build/

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


