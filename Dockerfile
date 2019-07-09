# This Dockerfile is used to build an headles vnc image based on Centos

FROM scientificlinux/sl:7

MAINTAINER Pengfei Ding "dingpf@fnal.gov"
ENV REFRESHED_AT 2019-03-12

RUN yum clean all \
 && yum -y install epel-release \
 && yum -y update \
 && yum -y install yum-plugin-priorities \
 subversion asciidoc bzip2-devel \
 fontconfig-devel freetype-devel gdbm-devel glibc-devel \
 ncurses-devel openssl-devel openldap-devel readline-devel \
 autoconf automake libtool swig texinfo tcl-devel tk-devel \
 xz-devel xmlto zlib-devel libcurl-devel libjpeg-turbo-devel \
 libpng-devel libstdc++-devel libuuid-devel libX11-devel \
 libXext-devel libXft-devel libXi-devel libXrender-devel \
 libXt-devel libXpm-devel libXmu-devel mesa-libGL-devel \
 mesa-libGLU-devel perl-DBD-SQLite perl-ExtUtils-MakeMaker \
 gcc gcc-c++ libgcc.i686 glibc-devel.i686 libstdc++.i686 libffi-devel \
 && yum -y install yum-plugin-priorities \
 nc perl expat-devel gdb time tar zip xz bzip2 patch sudo which strace \
 openssh-clients rsync tmux svn git wget cmake \
 gcc gstreamer gtk2-devel xterm \
 gstreamer-plugins-base-devel  \
 vim which net-tools xorg-x11-fonts* \
 xorg-x11-server-utils xorg-x11-twm dbus dbus-x11 \
 libuuid-devel wget redhat-lsb-core openssh-server \
  && yum clean all

RUN yum clean all \
 && yum --enablerepo=epel -y install htop osg-wn-client \
 libconfuse-devel x11vnc xvfb nss_wrapper gettext \
 && yum clean all

RUN yum clean all \
 && yum -y install java-11-openjdk \
 && yum clean all


ENV UPS_OVERRIDE="-H Linux64bit+3.10-2.17"

RUN dbus-uuidgen > /var/lib/dbus/machine-id

# Install No VNC
ENV NO_VNC_DIR=/scratch/noVNC
RUN mkdir -p $NO_VNC_DIR/utils/websockify \
 && wget -qO- https://github.com/novnc/noVNC/archive/v0.6.2.tar.gz | tar xz --strip 1 -C $NO_VNC_DIR \
 && wget -qO- https://github.com/novnc/websockify/archive/v0.6.1.tar.gz | tar xz --strip 1 -C $NO_VNC_DIR/utils/websockify \
 && chmod +x -v $NO_VNC_DIR/utils/*.sh \
 && ln -s $NO_VNC_DIR/vnc_auto.html $NO_VNC_DIR/index.html

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV DISPLAY=:1 \
    VNC_PORT=5900 \
    NO_VNC_PORT=6900 \
    VNC_PW=password \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_VIEW_ONLY=false
EXPOSE $VNC_PORT $NO_VNC_PORT

ENV TERM=xterm


# Create a me user (UID and GID should match the Mac user), add to suoders, and switch to it
ENV USERNAME=me

ARG MYUID
ENV MYUID=${MYUID:-1000}
ARG MYGID
ENV MYGID=${MYGID:-100}

RUN useradd -u $MYUID -g $MYGID -ms /bin/bash $USERNAME && \
      echo "$USERNAME ALL=(ALL)   NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME

ADD start-xvnc.sh /home/$USERNAME

ENTRYPOINT ["/bin/bash"]
