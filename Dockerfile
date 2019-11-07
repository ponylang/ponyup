FROM ponylang/ponyup-ci-ponyc-release:latest AS build

WORKDIR /src/ponyup

COPY Makefile LICENSE VERSION bundle.json /src/ponyup/

WORKDIR /src/ponyup/cmd

COPY cmd /src/ponyup/cmd/

WORKDIR /src/ponyup

RUN make ssl=0.9.0 arch=x86-64 static=true linker=bfd config=release

FROM alpine:3.10

COPY --from=build /src/ponyup/build/release/ponyup /usr/local/bin/ponyup

CMD ponyup
