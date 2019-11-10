FROM ponylang/ponyup-ci-x86-64-unknown-linux-builder:release AS build

WORKDIR /src/ponyup

COPY Makefile LICENSE VERSION bundle.json /src/ponyup/

WORKDIR /src/ponyup/cmd

COPY cmd /src/ponyup/cmd/

WORKDIR /src/ponyup

RUN make arch=x86-64 static=true linker=bfd config=release

FROM alpine:3.10

COPY --from=build /src/ponyup/build/release/ponyup /usr/local/bin/ponyup

CMD ponyup
