# This Dockerfile is used to build an headles vnc image based on Centos

FROM scientificlinux/sl:7

MAINTAINER Chris Backhouse "c.backhouse@ucl.ac.uk"
ENV REFRESHED_AT 2020-02-19

RUN yum clean all \
 && yum -y install epel-release \
 && yum -y update \
 && yum -y install yum-plugin-priorities \
 tar zip xz bzip2 patch sudo which openssh-clients git wget cmake3 \
 which redhat-lsb-core \
 libXft libXpm libSM libXext \
 && yum clean all

# libstdc++-devel \
# gcc gcc-c++ libgcc.i686 glibc-devel glibc-devel.i686 libstdc++.i686 \

# Get a decent compiler
RUN yum clean all \
    && yum -y install yum-conf-softwarecollections \
    && yum -y install devtoolset-7 \
    && yum clean all

RUN scl enable devtoolset-7 bash # TODO does this persist the rest of the file?

# Sigh, need new version for GIT_SSH_COMMAND
RUN yum clean all && yum install rh-git29 && yum clean all

RUN mkdir /nova

RUN cd /nova \
    && wget -qO- https://root.cern/download/root_v6.18.04.Linux-centos7-x86_64-gcc4.8.tar.gz | tar -xz \
    && source root/bin/thisroot.sh

# This is set on the docker build configuration, and forwarded through to this
# script by hooks/build. It only grants read-only access to the repository that
# will be checked out in this image anyway.
ARG ID_RSA_PRIV
RUN echo ${ID_RSA_PRIV} > /nova/id_rsa && chmod 400 /nova/id_rsa

RUN cd /nova/ \
    && cat /nova/id_rsa \
    && GIT_SSH_COMMAND='ssh -vvvv -i /nova/id_rsa' scl enable rh-git29 git clone git@github.com:novaexperiment/jointfit_novat2k.git \
    || true # make infallible

RUN cd /nova/jointfit_novat2k/ && mkdir build && cd build && cmake3 .. && make install || true

RUN cd /nova \
    && git clone git@github.com:pjdunne/DummyLLH.git \
    || true # make infallible

run cd /nova && git clone https://github.com/cjbackhouse/bifrost.git

RUN echo 'echo Test' > /nova/run.sh && chmod +x /nova/run.sh

# CHRIS
# ENV UPS_OVERRIDE="-H Linux64bit+3.10-2.17"

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

ENV TERM=xterm


# Create a nova user (UID and GID should match the Mac user), add to suoders, and switch to it
ENV USERNAME=nova

ARG MYUID
ENV MYUID=${MYUID:-1000}
ARG MYGID
ENV MYGID=${MYGID:-100}

RUN useradd -u $MYUID -g $MYGID -ms /bin/bash $USERNAME && \
      echo "$USERNAME ALL=(ALL)   NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME

# ENTRYPOINT ["/bin/bash"]

CMD [ "/nova/run.sh" ]
