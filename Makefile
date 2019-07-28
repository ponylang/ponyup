SOURCE_FILES := $(shell find cmd -name \*.pony)
SSL_VERSION := openssl_1.1.x

ifeq ($(config),release)
	PONYC = ponyc
else
	PONYC = ponyc --debug
endif

build/ponyup: $(SOURCE_FILES)
	stable env $(PONYC) -D$(SSL_VERSION) -d cmd -o build -b ponyup

clean:
	rm -f build/*

test: build/ponyup
	./test/test.sh

.PHONY: clean test
