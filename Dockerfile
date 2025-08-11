FROM docker.io/almalinux:8.9

LABEL org.opencontainers.image.authors="Artur Sztuc <a.sztuc@ucl.ac.uk>"
LABEL org.opencontainers.image.description="Docker image with the NOvA CAFAna server for the joint NOvA-T2K group"

ENV REFRESHED_AT 2025-07-29

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y groupinstall "Development Tools" && \
    dnf -y install \
        sudo which git wget curl cmake make \
        tar zip xz bzip2 patch \
        openssh-clients redhat-lsb-core \
        libXft libXpm libSM libXext \
        gcc gcc-c++ xxhash xxhash-libs \
        cmake \
        && dnf clean all

RUN mkdir /nova

# Fetch ROOT binaries
RUN cd /nova \
    && wget -qO- https://root.cern/download/root_v6.30.06.Linux-almalinux8.9-x86_64-gcc8.5.tar.gz | tar -xz
#    && wget -qO- https://root.cern/download/root_v6.26.16.Linux-AlmaLinux8.9-x86_64-gcc8.5.tar.gz | tar -xz
#    && wget -qO- https://root.cern/download/root_v6.36.02.Linux-almalinux8.10-x86_64-gcc8.5.tar.gz | tar -xz
#    && wget -qO- https://root.cern/download/root_v6.18.04.Linux-centos7-x86_64-gcc4.8.tar.gz | tar -xz
#    && wget -qO- https://root.cern/download/root_v6.24.08.Linux-centos7-x86_64-gcc4.8.tar.gz | tar -xz

# For a local build, it's much easier to just check out the package beforehand
COPY jointfit_novat2k /nova/jointfit_novat2k

# Fetch NuDock from git
RUN cd /nova \
    && git clone --recurse-submodules https://github.com/ArturSztuc/nudock.git

# Build everything
RUN cd /nova/nudock/ && mkdir build_nudock && cd build_nudock && source /nova/root/bin/thisroot.sh && cmake -DCMAKE_INSTALL_PREFIX:PATH=/nova/jointfit_novat2k .. && make install

RUN cd /nova/jointfit_novat2k/ && mkdir build && cd build && source /nova/root/bin/thisroot.sh && cmake -DCMAKE_PREFIX_PATH=/nova/jointfit_novat2k .. && make install

# Create the CMD script
RUN echo -e '#!'"/bin/bash\nsource /nova/root/bin/thisroot.sh\nexport JOINTFIT_DIR=/nova/jointfit_novat2k/\necho Versions:\necho -n 'jointfit_novat2k: '\ncd \$JOINTFIT_DIR\ngit describe --tags\necho -n 'bifrost: '\ncd /nova/bifrost\ngit describe --tags\necho -n 'DummyLLH: '\ncd /nova/DummyLLH/\ngit describe --tags\ncd \`mktemp -d\`\nroot -l -b -q \$JOINTFIT_DIR/CAFAna/load_libs.C \$JOINTFIT_DIR/CAFAna/run.C++" > /nova/run.sh && chmod +x /nova/run.sh

RUN echo -e '#!'"/bin/bash\nsource /nova/root/bin/thisroot.sh\nexport JOINTFIT_DIR=/nova/jointfit_novat2k/\necho Versions:\necho -n 'jointfit_novat2k: '\ncd \$JOINTFIT_DIR\ngit describe --tags\necho -n 'bifrost: '\ncd /nova/bifrost\ngit describe --tags\necho -n 'DummyLLH: '\ncd /nova/DummyLLH/\ngit describe --tags\ncd \`mktemp -d\`\nroot -l -b -q \$JOINTFIT_DIR/CAFAna/load_libs.C \$JOINTFIT_DIR/CAFAna/run_client.C++" > /nova/run_client.sh && chmod +x /nova/run_client.sh


ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV TERM=xterm
ENV LD_LIBRARY_PATH=/nova/jointfit_novat2k/lib65:/nova/root/lib:$LD_LIBRARY_PATH

# Create a nova user (UID and GID should match the Mac user), add to suoders, and switch to it
ENV USERNAME=nova

ARG MYUID
ENV MYUID=${MYUID:-1000}
ARG MYGID
ENV MYGID=${MYGID:-100}

RUN useradd -u $MYUID -g $MYGID -ms /bin/bash $USERNAME && \
      echo "$USERNAME ALL=(ALL)   NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME

CMD [ "/nova/run.sh" ]