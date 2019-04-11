FROM centos/systemd

RUN yum -y install openssh-server sudo openssh-clients \
    epel-release python-docker-py iproute e2fsprogs
RUN systemctl enable sshd.service
EXPOSE 22

CMD ["/usr/sbin/init"]
