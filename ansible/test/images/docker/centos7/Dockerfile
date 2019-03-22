# https://github.com/chrismeyersfsu/provision_docker/tree/master/files
FROM centos:centos7
ENV container docker

RUN yum -y update; yum clean all

RUN yum -y swap -- remove systemd-container systemd-container-libs -- install systemd systemd-libs dbus fsck.ext4

RUN systemctl mask dev-mqueue.mount dev-hugepages.mount \
    systemd-remount-fs.service sys-kernel-config.mount \
    sys-kernel-debug.mount sys-fs-fuse-connections.mount \
    display-manager.service graphical.target systemd-logind.service

RUN yum -y install openssh-server sudo openssh-clients \
    epel-release python-docker-py iproute
RUN sed -i 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -q -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa && \
    ssh-keygen -q -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
RUN echo 'root:docker.io' | chpasswd
RUN systemctl enable sshd.service

# firewalld needs this .. and I needs my firewalld
ADD dbus.service /etc/systemd/system/dbus.service
RUN systemctl enable dbus.service

VOLUME [ "/sys/fs/cgroup" ]
VOLUME ["/run"]

EXPOSE 22

CMD ["/usr/sbin/init"]
