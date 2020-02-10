ARG RELEASE
FROM ubuntu:${RELEASE}

# Systemd requires this env for ConditionVirtualization setting in unit files
ENV container docker

# Python2.7 required by ansible
RUN apt-get update && apt-get -y install dbus systemd openssh-server

# Create symlink python3 -> python
RUN ln -s /usr/bin/python3 /usr/bin/python

EXPOSE 22

CMD ["/sbin/init"]
