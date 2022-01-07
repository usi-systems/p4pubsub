FROM debian:jessie
MAINTAINER Theo Jepsen <jepset@usi.ch>

# Install dependencies and some useful tools.
ENV DEV_TOOLS vim \
              zsh \
              colordiff \
              tcpdump \
              less \
              ethtool

ENV SDE_DEPS  sudo \
              graphviz \
              zlib1g-dev \
              libpcap-dev \
              libc-ares-dev \
              autoconf \
              automake \
              build-essential \
              ca-certificates \
              cmake \
              curl \
              git \
              libssl-dev \
              libtool \
              make \
              mktemp \
              pkg-config \
              python \
              python-dev \
              python-ipaddr \
              python-pip \
              python-scapy \
              python-setuptools \
              python-ply \
              libboost-dev \
              libboost-filesystem-dev \
              libboost-iostreams1.55-dev \
              libboost-program-options-dev \
              libboost-system-dev \
              libboost-test-dev \
              libboost-thread-dev \
              unzip

# I'm not sure these are required:
ENV MAYBE_DEPS bison \
              flex \
              cpp \
              libc6-dev \
              libevent-dev \
              libffi-dev \
              libfl-dev \
              libgc-dev \
              libgc1c2 \
              libgflags-dev \
              libgmp-dev \
              libgmp10 \
              libgmpxx4ldbl \
              libjudy-dev \
              libreadline6 \
              libreadline6-dev


# Ignore questions when installing with apt-get:
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends $DEV_TOOLS $SDE_DEPS

# Fix to get tcpdump working
RUN mv /usr/sbin/tcpdump /usr/bin/tcpdump

# Install dependencies.tar
COPY dependencies_20181010.tar /tmp
RUN tar xf /tmp/dependencies_20181010.tar -C /tmp && rm /tmp/dependencies_20181010.tar
WORKDIR /tmp/dependencies
RUN sed -i 's/^make/make -j4/' install.sh && ./install.sh

# Install the SDE
COPY bf-sde-8.4.0.tar /tmp
RUN tar xf /tmp/bf-sde-8.4.0.tar -C / && rm /tmp/bf-sde-8.4.0.tar
COPY sde_build.sh p4_build.sh /bf-sde-8.4.0/

ENV PATH "/bf-sde-8.4.0/install/bin:${PATH}"
ENV SDE=/bf-sde-8.4.0
ENV SDE_INSTALL=/bf-sde-8.4.0/install

WORKDIR /bf-sde-8.4.0
RUN PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig/ ./sde_build.sh -q \
                --bf-drivers-extra-flags="--without-kdrv" -e 9

ENTRYPOINT ["/bin/zsh"]
