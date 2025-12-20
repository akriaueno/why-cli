FROM archlinux:base
RUN pacman -Syu --noconfirm bash ca-certificates coreutils \
  && pacman -Scc --noconfirm
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/arch/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
