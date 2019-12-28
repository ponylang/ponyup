prefix ?= /usr/local
destdir ?= $(prefix)
config ?= release
arch ?=
static ?= false
linker ?=

ssl ?= 0.9.0
PONYC_FLAGS ?=

BUILD_DIR ?= build/$(config)
DEPS_DIR ?= .deps
SRC_DIR ?= cmd
binary := $(BUILD_DIR)/ponyup

ifdef config
	ifeq (,$(filter $(config),debug release))
		$(error Unknown configuration "$(config)")
	endif
endif

ifeq ($(config),debug)
	PONYC_FLAGS += --debug
endif

ifeq ($(ssl), 1.1.x)
	PONYC_FLAGS += -Dopenssl_1.1.x
else ifeq ($(ssl), 0.9.0)
	PONYC_FLAGS += -Dopenssl_0.9.0
else
	$(error Unknown SSL version "$(ssl)". Must set using 'ssl=FOO')
endif

ifneq ($(arch),)
	PONYC_FLAGS += --cpu $(arch)
endif

ifdef static
	ifeq (,$(filter $(static),true false))
		$(error "static must be true or false)
	endif
endif

ifeq ($(static),true)
	LINKER += --static
endif

ifneq ($(linker),)
	LINKER += --link-ldcmd=$(linker)
endif

# Default to version from `VERSION` file but allowing overridding on the
# make command line like:
# make version="nightly-19710702"
# overridden version *should not* contain spaces or characters that aren't
# legal in filesystem path names
ifndef version
	version := $(shell cat VERSION)
	ifneq ($(wildcard .git),)
		sha := $(shell git rev-parse --short HEAD)
		tag := $(version)-$(sha)
	else
		tag := $(version)
	endif
else
	foo := $(shell touch VERSION)
	tag := $(version)
endif

SOURCE_FILES := $(shell find $(SRC_DIR) -path $(SRC_DIR)/test -prune -o -name \*.pony)
VERSION := "$(tag) [$(config)]"
GEN_FILES_IN := $(shell find $(SRC_DIR) -name \*.pony.in)
GEN_FILES = $(patsubst %.pony.in, %.pony, $(GEN_FILES_IN))

%.pony: %.pony.in VERSION
	sed s/%%VERSION%%/$(version)/ $< > $@

$(DEPS_DIR):
	stable fetch

$(binary): $(GEN_FILES) $(SOURCE_FILES) build/libdetect.a | $(BUILD_DIR) $(DEPS_DIR)
	stable env ponyc $(PONYC_FLAGS) $(LINKER) $(SRC_DIR) -o $(BUILD_DIR) -b ponyup

build/libdetect.a: $(SRC_DIR)/detect_libc.c
	@mkdir -p $(BUILD_DIR)
	cc -c $^ -o $(BUILD_DIR)/detect_libc.o \
		-ansi -Wall -Wextra -Wpedantic -fpic
	ar -rcs $@ $(BUILD_DIR)/detect_libc.o

install: $(binary)
	@echo "install"
	mkdir -p $(DESTDIR)$(prefix)/bin
	cp $^ $(DESTDIR)$(prefix)/bin

SOURCE_FILES := $(shell find cmd -name \*.pony)

test: $(binary)
	stable env ponyc $(PONYC_FLAGS) $(LINKER) test -o $(BUILD_DIR) -b test
	$(BUILD_DIR)/test ${ponytest_args}

clean:
	rm -rf $(BUILD_DIR) $(GEN_FILES)

all: test $(binary)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: all clean install test
