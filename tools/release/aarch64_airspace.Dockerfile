FROM quay.io/pypa/manylinux_2_28_aarch64:latest AS env
# note: the image preinstalls cmake and swig, but :latest drifts (4.4.x as of
# 2026-07); pin both below so the toolchain matches the Mac dev machines that
# regenerate the committed go/ sources.
# To build on an x86_64 host, QEMU/binfmt is required (slow); prefer an arm64 host.
# see https://github.com/multiarch/qemu-user-static#getting-started

#############
##  SETUP  ##
#############
RUN dnf -y update \
&& dnf -y group install 'Development Tools' \
&& dnf -y install wget curl \
 pcre2-devel openssl \
 which redhat-lsb-core \
 pkgconfig autoconf libtool zlib-devel \
&& dnf clean all \
&& rm -rf /var/cache/dnf

ENTRYPOINT ["/usr/bin/bash", "-c"]
CMD ["/usr/bin/bash"]

# Remove the image's pipx-managed cmake/swig shims: they are symlinks in
# /usr/local/bin, and installing over a symlink writes through into the pipx
# venv, leaving a cmake that can't find CMAKE_ROOT
RUN rm -f /usr/local/bin/cmake /usr/local/bin/ctest /usr/local/bin/cpack /usr/local/bin/ccmake /usr/local/bin/swig

# Install CMake 3.31.2
RUN wget -q --no-check-certificate "https://github.com/Kitware/CMake/releases/download/v3.31.2/cmake-3.31.2-linux-aarch64.sh" \
&& chmod a+x cmake-3.31.2-linux-aarch64.sh \
&& ./cmake-3.31.2-linux-aarch64.sh --prefix=/usr/local --skip-license \
&& rm cmake-3.31.2-linux-aarch64.sh
RUN test "$(readlink -f "$(command -v cmake)")" = "/usr/local/bin/cmake" \
 && cmake --version | grep -F 3.31.2

# Install Swig 4.3.1 (image ships 4.3.0; keep in sync with dev machines so
# generated wrappers match the committed go/ sources)
RUN curl --location-trusted \
 --remote-name "https://downloads.sourceforge.net/project/swig/swig/swig-4.3.1/swig-4.3.1.tar.gz" \
 -o swig-4.3.1.tar.gz \
&& tar xvf swig-4.3.1.tar.gz \
&& rm swig-4.3.1.tar.gz \
&& cd swig-4.3.1 \
&& ./configure --prefix=/usr/local \
&& make -j 4 \
&& make install \
&& cd .. \
&& rm -rf swig-4.3.1
RUN swig -version | grep -F 4.3.1

# Install Go 1.26.5
RUN wget -q --no-check-certificate "https://go.dev/dl/go1.26.5.linux-arm64.tar.gz" \
&& rm -rf /usr/local/go \
&& tar -C /usr/local -xzf go1.26.5.linux-arm64.tar.gz \
&& rm go1.26.5.linux-arm64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
RUN GOBIN=/usr/local/go/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.10
RUN go version

ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

################
##  OR-TOOLS  ##
################
FROM env AS devel
WORKDIR /root

# Download sources
# use ORTOOLS_GIT_SHA1 to modify the command
# i.e. avoid docker reusing the cache when new commit is pushed
ARG ORTOOLS_GIT_BRANCH
ENV ORTOOLS_GIT_BRANCH=${ORTOOLS_GIT_BRANCH:-airspace}
ARG ORTOOLS_GIT_SHA1
ENV ORTOOLS_GIT_SHA1=${ORTOOLS_GIT_SHA1:-unknown}
# RUN git clone -b "${ORTOOLS_GIT_BRANCH}" --single-branch https://github.com/AirspaceTechnologies/or-tools \
# && cd or-tools \
# && git reset --hard "${ORTOOLS_GIT_SHA1}"
COPY . /root/or-tools

# Build delivery
FROM devel AS delivery
WORKDIR /root/or-tools

# OFF when the delivery is built under cross-arch emulation (see go.cmake)
ARG GO_TEST_RACE=ON
ENV GO_TEST_RACE=${GO_TEST_RACE}

RUN ./native.sh
