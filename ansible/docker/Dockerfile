FROM alpine:3.8

ARG ansible_version=2.7.8
ARG mitogen_version=0.2.7
LABEL ansible_version=$ansible_version vendor=Samsung

# Install Ansible build dependencies
RUN apk --no-cache update \
&& apk --no-cache --update add --virtual build-dependencies \
  gcc \
  make \
  musl-dev \
  libffi-dev \
  openssl-dev \
  python3-dev \
&& apk add --no-cache \
  python3 \
  py3-pip \
  openssh-client \
  openssl \
  py3-openssl \
  openssh \
  sshpass \
&& pip3 install --upgrade pip \
&& pip3 install \
  ansible==$ansible_version \
  jmespath \
  netaddr \
  jsonpointer \
&& apk del build-dependencies && rm -rf /var/cache/apk/* && rm -rf /root/.cache \
&& wget -O /tmp/mitogen.zip https://github.com/dw/mitogen/archive/v${mitogen_version}.zip \
&& unzip /tmp/mitogen.zip -d /tmp \
&& mkdir -p /ansible/plugins/mitogen \
&& mv /tmp/mitogen-${mitogen_version}/* /ansible/plugins/mitogen \
&& rm -rf /tmp/mitogen-${mitogen_version} \
&& rm /tmp/mitogen.zip

ENV ANSIBLE_HOST_KEY_CHECKING false
ENV ANSIBLE_RETRY_FILES_ENABLED false

WORKDIR /ansible

ENTRYPOINT ["ansible-playbook"]
