ARG RELEASE
FROM ubuntu:${RELEASE}

# Systemd requires this env for ConditionVirtualization setting in unit files
ENV container docker

# Install necessary packages
RUN apt-get update && apt-get -y install dbus systemd openssh-server iproute2 python3-docker

# Create symlink python3 -> python
RUN ln -s /usr/bin/python3 /usr/bin/python

EXPOSE 22

CMD ["/sbin/init"]
