FROM centos/systemd

RUN yum -y update && yum clean all

RUN yum -y install openssh-server sudo openssh-clients \
    epel-release python-docker-py iproute
RUN systemctl enable sshd.service

VOLUME ["/run"]

EXPOSE 22

CMD ["/usr/sbin/init"]
