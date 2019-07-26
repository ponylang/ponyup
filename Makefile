SOURCE_FILES := $(shell find cmd -name \*.pony)
SSL_VERSION := openssl_1.1.x

ifeq ($(config),release)
	PONYC = ponyc
else
	PONYC = ponyc --debug
endif

ponyup: $(SOURCE_FILES)
	stable env $(PONYC) -D$(SSL_VERSION) -d cmd -o build -b $@

clean:
	rm -f build/*

.PHONY: clean
