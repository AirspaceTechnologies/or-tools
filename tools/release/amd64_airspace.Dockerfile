FROM quay.io/pypa/manylinux2014_x86_64:latest AS env

#############
##  SETUP  ##
#############
RUN yum -y update \
&& yum -y groupinstall 'Development Tools' \
&& yum -y install wget curl \
 pcre2-devel openssl \
 which redhat-lsb-core \
 pkgconfig autoconf libtool zlib-devel \
&& yum clean all \
&& rm -rf /var/cache/yum

ENTRYPOINT ["/usr/bin/bash", "-c"]
CMD ["/usr/bin/bash"]

# Install CMake v3.26.4
RUN wget -q --no-check-certificate "https://cmake.org/files/v3.26/cmake-3.26.4-linux-x86_64.sh" \
&& chmod a+x cmake-3.26.4-linux-x86_64.sh \
&& ./cmake-3.26.4-linux-x86_64.sh --prefix=/usr --skip-license \
&& rm cmake-3.26.4-linux-x86_64.sh

# Install Swig 4.3.0
RUN curl --location-trusted \
 --remote-name "https://downloads.sourceforge.net/project/swig/swig/swig-4.3.0/swig-4.3.0.tar.gz" \
 -o swig-4.3.0.tar.gz \
&& tar xvf swig-4.3.0.tar.gz \
&& rm swig-4.3.0.tar.gz \
&& cd swig-4.3.0 \
&& ./configure --prefix=/usr \
&& make -j 4 \
&& make install \
&& cd .. \
&& rm -rf swig-4.3.0

# Install Go 1.23.0
RUN wget -q --no-check-certificate "https://go.dev/dl/go1.23.0.linux-amd64.tar.gz" \
&& rm -rf /usr/local/go \
&& tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz \
&& rm go1.23.0.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
RUN GOBIN=/usr/local/go/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.33
RUN go version

# Openssl 1.1
RUN yum -y update \
&& yum -y install epel-release \
&& yum repolist \
&& yum -y install openssl11

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
ENV ORTOOLS_GIT_BRANCH ${ORTOOLS_GIT_BRANCH:-airspace}
ARG ORTOOLS_GIT_SHA1
ENV ORTOOLS_GIT_SHA1 ${ORTOOLS_GIT_SHA1:-unknown}
# RUN git clone -b "${ORTOOLS_GIT_BRANCH}" --single-branch https://github.com/AirspaceTechnologies/or-tools \
# && cd or-tools \
# && git reset --hard "${ORTOOLS_GIT_SHA1}"
COPY . /root/or-tools

# Build delivery
FROM devel AS delivery
WORKDIR /root/or-tools

RUN ./native.sh