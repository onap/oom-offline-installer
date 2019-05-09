FROM quay.io/ansible/molecule:2.20

ARG USER_ID
ARG GROUP_ID
ARG DOCKER_GROUP_ID
ARG DOCKER_USER

# When user/group provided, create user to have matching ids (for the host user)
# to avoid this docker writing files as root owned
RUN if [ ${USER_ID:-0} -ne 0 ] && [ ${GROUP_ID:-0} -ne 0 ]; then \
    # shadow needed for addgroup
    # sshpass needed for accessing docker_host (localhost) with ssh and without password prompt
    apk --no-cache add shadow sshpass && \
    addgroup -g ${GROUP_ID} ${DOCKER_USER} && \
    adduser -D -u ${USER_ID} -G ${DOCKER_USER} ${DOCKER_USER} && \
    # Add user to same docker group as in docker_host to be able to use docker driver as sudo
    groupadd docker-host -f -g ${DOCKER_GROUP_ID} && \
    usermod -aG ${DOCKER_GROUP_ID} ${DOCKER_USER} \
;fi

USER ${DOCKER_USER}

