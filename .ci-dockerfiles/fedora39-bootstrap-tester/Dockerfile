FROM fedora:39

RUN dnf install -y clang \
  git \
  lsb-release \
  openssl-devel \
 && dnf -y autoremove \
 && dnf -y clean all \
 && rm -rf /var/cache/dnf*

RUN git config --global --add safe.directory /__w/ponyup/ponyup
