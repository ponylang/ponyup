FROM fedora:42

RUN dnf install -y binutils-gold \
  clang \
  git \
  lsb-release \
  openssl-devel \
 && dnf -y autoremove \
 && dnf -y clean all \
 && rm -rf /var/cache/dnf*

RUN git config --global --add safe.directory /__w/ponyup/ponyup
