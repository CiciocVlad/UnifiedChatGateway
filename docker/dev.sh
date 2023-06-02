#!/usr/bin/env sh

BUILD_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd $BUILD_DIR/.. && pwd)
FAKE_HOME=$BUILD_DIR/.HOME_${TARGET_OS:?}

# Prepare fake home to store mix/hex cache
mkdir -p $FAKE_HOME/.ssh

# Mix needs to checkout private repositories, so forward ssh-agent.
#
# Bind the project directory so the resulting files are available outside of container.
# To ensure all the new files belong to the current user, run container with its uid/gid.
# However git and other tools want the uid and the gid to exist in
# /etc/passwd and /etc/group, so bind the real ones to the container (readonly).
exec docker run --rm \
       -e SSH_AUTH_SOCK=/ssh_agent \
       -v $SSH_AUTH_SOCK:/ssh_agent \
       -v $FAKE_HOME:$HOME \
       -v $HOME/.ssh/known_hosts:$HOME/.ssh/known_hosts:ro \
       -v /etc/passwd:/etc/passwd:ro \
       -v /etc/group:/etc/group:ro \
       -v $PROJECT_DIR:/unified-chat-gateway \
       -w /unified-chat-gateway \
       -u `id -u`:`id -g` \
       ${@:-\
          -p 8081:8081 \
          -it docker.pcpdev.local/builder/${TARGET_OS:?}/pcp-node-1.8.0}
