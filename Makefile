PACKAGE_NAME := packageRepo
PACKAGE_VERSION := $(shell bash -c '. src/lib/$(PACKAGE_NAME) 2>/dev/null; package_repo::version')
INSTALL_PATH := $(shell python -c 'import sys; print sys.prefix if hasattr(sys, "real_prefix") else exit(255)' 2>/dev/null || echo "/usr/local")
LIB_COMPONENTS := $(wildcard src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/*)
BIN_COMPONENTS := $(foreach name, $(wildcard src/bin/*), build/bin/$(notdir $(name)))
DIR_COMPONENTS := $(foreach name, bin share lib, build/$(name)) build/share/$(PACKAGE_NAME)

# Webserve
BIN_COMPONENTS += build/share/$(PACKAGE_NAME)/tools/webserve
DIR_COMPONENTS += build/share/$(PACKAGE_NAME)/tools

.PHONY: tests clean help build

all: build

help:
	@echo "Usage: make [build|tests|all|clean|version|install]"

build: build/lib/$(PACKAGE_NAME) $(BIN_COMPONENTS)

tests: build
	@PATH="$(shell readlink -f build/bin):$(PATH)" unittests/testsuite

install-private: tests $(HOME)/bin
	@echo "Privately installing into directory '$(HOME)'"
	@echo $$PATH | tr '\\:' '\n' | grep -q '^'"$$HOME/bin"'$$'
	@rsync -az build/ $(HOME)/

install: tests
	@echo "Installing into directory '$(INSTALL_PATH)'"
	@rsync -az build/ $(INSTALL_PATH)/

version: all
	@build/bin/packagerepo --version

build/bin/%: build/lib/$(PACKAGE_NAME) build/bin | src/bin
	@install -m 755 src/bin/$(notdir $@) $@

build/lib/$(PACKAGE_NAME): build/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION) build/lib src/lib/$(PACKAGE_NAME)
	@install -m 755 src/lib/$(PACKAGE_NAME) $@

build/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION): build/lib $(LIB_COMPONENTS)
	@rsync -az src/lib/$(PACKAGE_NAME)-$(PACKAGE_VERSION)/ $@/

build/share/$(PACKAGE_NAME)/tools/webserve: build/share/$(PACKAGE_NAME)/tools checkouts/webserve
	@rsync -az checkouts/webserve/build/bin/$(notdir $@) $@

build/share/$(PACKAGE_NAME)/examples: build/share/$(PACKAGE_NAME)
	@rsync -az examples/ $@/

checkouts/webserve: checkouts
	@(cd $@ >/dev/null 2>&1 && git pull || git clone https://github.com/damionw/webserve.git $@)
	@$(MAKE) -C $@ clean tests

checkouts:
	@install -d $@

$(DIR_COMPONENTS):
	@install -d $@

clean:
	-@rm -rf build testdata
