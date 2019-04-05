FROM centos/systemd

RUN yum -y install openssh-server
RUN systemctl enable sshd.service
EXPOSE 22

CMD ["/usr/sbin/init"]
