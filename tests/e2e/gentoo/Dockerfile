FROM gentoo/stage3:latest
ENV FEATURES="-sandbox -usersandbox"
RUN emerge --sync \
  && emerge --quiet app-portage/portage-utils
COPY tests/e2e/why-linux-amd64 /usr/local/bin/why
COPY tests/e2e/common.sh /test-common.sh
COPY tests/e2e/gentoo/test.sh /test.sh
ENTRYPOINT ["/bin/bash", "/test.sh"]
