FROM docker.io/centos:7.6.1810

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

# Get a decent compiler
RUN yum clean all \
    && yum -y install centos-release-scl \
    && yum -y install devtoolset-7 \
    && yum clean all

# Sigh, need new version for GIT_SSH_COMMAND
# RUN yum clean all && yum install -y rh-git218 && yum clean all

RUN mkdir /nova

# Fetch ROOT binaries
RUN cd /nova \
    && wget -qO- https://root.cern/download/root_v6.18.04.Linux-centos7-x86_64-gcc4.8.tar.gz | tar -xz

# Fetch DummyLLH from git
RUN cd /nova && git clone https://github.com/nova-t2k/DummyLLH.git

# Fetch Bifrost from git
RUN cd /nova && git clone https://github.com/nova-t2k/bifrost.git

# This ID_RSA_PRIV dance is to make things work on dockerhub

# This is set on the docker build configuration, and forwarded through to this
# script by hooks/build. It only grants read-only access to the repository that
# will be checked out in this image anyway.
#
# Because the key needs to be all one line in the web interface all the newlines are spaces. And that means I had to manually make all the spaces underscores.
# Undo that here.

# ARG ID_RSA_PRIV
# RUN echo ${ID_RSA_PRIV} | sed 's/ /\n/g' | sed 's/_/ /g' > /nova/id_rsa && chmod 400 /nova/id_rsa

# RUN cd /nova/ \
#    && GIT_SSH_COMMAND='ssh -i /nova/id_rsa -o StrictHostKeyChecking=no' scl enable rh-git218 'git clone git@github.com:novaexperiment/jointfit_novat2k.git'

# For a local build, it's much easier to just check out the package beforehand
COPY jointfit_novat2k /nova/jointfit_novat2k

# Build everything
RUN cd /nova/jointfit_novat2k/ && mkdir build && cd build && scl enable devtoolset-7 'source /nova/root/bin/thisroot.sh && cmake3 .. && make install'

# Create the CMD script
RUN echo -e '#!'"/bin/bash\nsource /nova/root/bin/thisroot.sh\nexport JOINTFIT_DIR=/nova/jointfit_novat2k/\necho Versions:\necho -n 'jointfit_novat2k: '\ncd \$JOINTFIT_DIR\ngit describe --tags\necho -n 'bifrost: '\ncd /nova/bifrost\ngit describe --tags\necho -n 'DummyLLH: '\ncd /nova/DummyLLH/\ngit describe --tags\ncd \`mktemp -d\`\nscl enable devtoolset-7 'root -l -b -q \$JOINTFIT_DIR/CAFAna/load_libs.C \$JOINTFIT_DIR/CAFAna/run.C++'" > /nova/run.sh && chmod +x /nova/run.sh


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
