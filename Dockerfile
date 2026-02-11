FROM docker.io/almalinux:8.9

LABEL org.opencontainers.image.authors="Artur Sztuc <a.sztuc@ucl.ac.uk>"
LABEL org.opencontainers.image.description="Docker image with the NOvA CAFAna server for the joint NOvA-T2K group"

ENV REFRESHED_AT 2025-07-29

# Install all the core software
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

# Install ROOT
RUN dnf -y install \
        root root-cli root-cling root-core root-fonts root-gdml \
        root-genvector root-geom root-graf root-gui \
        root-hbook root-hist root-icons root-io root-io-xml root-mathcore \
        root-mathmore root-matrix root-minuit root-minuit2 root-mlp \
        root-montecarlo-eg root-montecarlo-pythia8 root-multiproc root-net \
        root-net-auth root-net-davix root-net-rpdutils \ 
        root-netx root-physics root-roofit root-smatrix \ 
        root-splot root-sql-sqlite root-tmva root-tmva-gui \
        root-tmva-python root-tree root-tree-player root-tree-viewer \
        root-unfold root-unuran

RUN mkdir /nova

# Fetch NuDock from git
RUN cd /nova \
    && git clone --recurse-submodules https://github.com/NuDock/nudock.git

# For a local build, it's much easier to just check out the package beforehand
COPY jointfit_novat2k /nova/jointfit_novat2k

# Build everything
RUN cd /nova/nudock/ && cmake -B build -DCMAKE_INSTALL_PREFIX:PATH=/nova/jointfit_novat2k  && cmake --build build && cmake --install build

RUN cd /nova/jointfit_novat2k/ && ls && cmake -B build -DCMAKE_PREFIX_PATH=/nova/jointfit_novat2k && cmake --build build && cmake --install build

RUN echo -e '#!'"/bin/bash\nexport JOINTFIT_DIR=/nova/jointfit_novat2k/\necho Versions:\necho -n 'jointfit_novat2k: '\ncd \$JOINTFIT_DIR\ngit describe --tags\ncd \`mktemp -d\`\nroot -l -b -q \$JOINTFIT_DIR/CAFAna/load_libs.C \$JOINTFIT_DIR/CAFAna/run.C++" > /nova/run.sh && chmod +x /nova/run.sh

RUN echo -e '#!'"/bin/bash\nexport JOINTFIT_DIR=/nova/jointfit_novat2k/\necho Versions:\necho -n 'jointfit_novat2k: '\ncd \$JOINTFIT_DIR\ngit describe --tags\ncd \`mktemp -d\`\nroot -l -b -q \$JOINTFIT_DIR/CAFAna/load_libs.C \$JOINTFIT_DIR/CAFAna/run_client.C++" > /nova/run_client.sh && chmod +x /nova/run_client.sh


ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV TERM=xterm
ENV LD_LIBRARY_PATH=/nova/jointfit_novat2k/lib64

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
