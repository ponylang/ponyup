#!/bin/sh

# This script performs simple platform detection and standard pony tools

set -o errexit
set -o nounset
set -o pipefail

# TODO: windows support

main() {
    PONYUP_HOME=${PONYUP_HOME:-"$HOME/.ponyup"}
    export PONYUP_HOME
    log "PONYUP_HOME set to $PONYUP_HOME"
    make_ponyup_home

    local _arch ; _arch="$(get_arch)"
    log "default host triple: $_arch"

    # TODO install ponyup for $_arch into $PONYUP_HOME/bin
}

make_ponyup_home() {
    mkdir -p "$PONYUP_HOME/bin"
}

get_arch() {
    local _cpu ; _cpu="$(get_cpu)"
    local _os ; _os="$(get_os)"

    # Darwin `uname -s` lies
    if [ "$_os" = "Darwin" ] && [ "$_cpu" = "i386" ]; then
        if sysctl hw.optional.x86_64 | grep -q ": 1"; then
            _cpu="x86_64"
        fi
    fi

    echo "$_cpu-$_os"
}

get_cpu() {
    local _cpu ; _cpu="$(uname -m)"

    case "$_cpu" in
        # "i386" | "i486" | "i686" | "i786" | "x86")
        #     _cpu="i686"
        #     ;;
        "x86_64" | "x86-64" | "x64" | "amd64")
            _cpu="x86_64"
            ;;
        # "arm" | "armv6l" | "armv7l" | "armv8l")
        #     _cpu="arm"
        #     ;;
        # "aarch64")
        #     ;;
        *)
            err "Unsupported CPU type: $_cpu"
    esac

    echo "$_cpu"
}

get_os() {
    local _os ; _os="$(uname -s)"

    if [ "$_os" = "Linux" ] && [ "$(uname -o)" = "Android" ]; then
        _os="Android"
    fi

    case "$_os" in
        # "Android")
        #     _os="linux-android"
        #     ;;
        "Linux")
            _os="unknown-linux-gnu"
            ;;
        # "FreeBSD")
        #     _os="unknown-freebsd"
        #     ;;
        # "NetBSD")
        #     _os="unknown-netbsd"
        #     ;;
        # "DragonFly")
        #     _os="unknown-dragonfly"
        #     ;;
        "Darwin")
            _os="apple-darwin"
            ;;
        # "MINGW"* | "MSYS"* | "CYGWIN"*)
        #     _os="pc-windows-gnu"
        #     ;;
        *)
            err "Unsupported OS type: $_os"
    esac

    echo "$_os"
}

log() {
    echo "ponyup: $1"
}

err() {
    log "$1" >&2
    exit 1
}

main "$@"
