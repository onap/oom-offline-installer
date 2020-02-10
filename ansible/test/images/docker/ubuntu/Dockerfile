ARG RELEASE
FROM ubuntu:${RELEASE}

# Systemd requires this env for ConditionVirtualization setting in unit files
ENV container docker

# Python2.7 required by ansible
RUN apt-get update && apt-get -y install dbus systemd python openssh-server iproute2 python-docker

# RUN pip install docker-py

EXPOSE 22

CMD ["/sbin/init"]
