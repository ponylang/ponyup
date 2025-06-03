FROM ghcr.io/ponylang/shared-docker-ci-x86-64-unknown-linux-builder-with-libressl-3.9.1:release AS build

WORKDIR /src/ponyup

COPY Makefile LICENSE VERSION corral.json /src/ponyup/

WORKDIR /src/ponyup/cmd

COPY cmd /src/ponyup/cmd/

WORKDIR /src/ponyup

RUN make arch=x86-64 static=true linker=bfd config=release

FROM scratch

COPY --from=build /src/ponyup/build/release/ponyup /usr/local/bin/ponyup

CMD ponyup
