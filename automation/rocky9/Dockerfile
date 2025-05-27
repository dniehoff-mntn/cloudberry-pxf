FROM rockylinux/rockylinux:9
ENV TZ="UTC"

ARG CODEBASE_VERSION_VAR=${CODEBASE_VERSION_VAR}

ENV container=docker
ENV MULTINODE=false

RUN dnf update -y && \
  dnf install -y systemd \
  systemd-libs && \
  dnf clean all

# Clean up unnecessary systemd units
RUN [ -d /lib/systemd/system/sysinit.target.wants ] && find /lib/systemd/system/sysinit.target.wants/ -type l -not -name 'systemd-tmpfiles-setup.service' -delete || echo "Directory /lib/systemd/system/sysinit.target.wants does not exist" && \
  [ -d /lib/systemd/system/multi-user.target.wants ] && find /lib/systemd/system/multi-user.target.wants/ -type l -delete || echo "Directory /lib/systemd/system/multi-user.target.wants does not exist" && \
  find /etc/systemd/system/*.wants/ -type l -delete || echo "Directory /etc/systemd/system/*.wants does not exist" && \
  [ -d /lib/systemd/system/local-fs.target.wants ] && find /lib/systemd/system/local-fs.target.wants/ -type l -delete || echo "Directory /lib/systemd/system/local-fs.target.wants does not exist" && \
  [ -d /lib/systemd/system/sockets.target.wants ] && find /lib/systemd/system/sockets.target.wants/ -type l -not -name '*udev*' -delete || echo "Directory /lib/systemd/system/sockets.target.wants does not exist" && \
  [ -d /lib/systemd/system/basic.target.wants ] && find /lib/systemd/system/basic.target.wants/ -type l -delete || echo "Directory /lib/systemd/system/basic.target.wants does not exist" && \
  [ -d /lib/systemd/system/anaconda.target.wants ] && find /lib/systemd/system/anaconda.target.wants/ -type l -delete || echo "Directory /lib/systemd/system/anaconda.target.wants does not exist"

RUN     echo root:cbdb@123 | chpasswd && \
  dnf makecache && \
  dnf install -y yum-utils \
  epel-release \
  git && \
  yum-config-manager --disable epel-cisco-openh264 && \
  dnf makecache && \
  yum-config-manager --disable epel && \
  dnf install -y --enablerepo=epel \
  the_silver_searcher \
  bat \
  htop && \
  dnf install -y bison \
  cmake3 \
  ed \
  flex \
  gcc \
  gcc-c++ \
  glibc-langpack-en \
  go \
  initscripts \
  iproute \
  less \
  m4 \
  net-tools \
  openssh-clients \
  openssh-server \
  passwd \
  perl \
  rsync \
  sudo \
  tar \
  unzip \
  util-linux-ng \
  wget \
  sshpass \
  which && \
  dnf install -y apr-devel \
  bzip2-devel \
  krb5-devel \
  libcurl-devel \
  libevent-devel \
  libxml2-devel \
  libzstd-devel \
  openldap-devel \
  openssl-devel \
  pam-devel \
  perl-ExtUtils-Embed \
  perl-Test-Simple \
  perl-core \
  python3-devel \
  readline-devel \
  zlib-devel && \
  dnf install -y --enablerepo=crb \
  libuv-devel \
  libyaml-devel \
  perl-IPC-Run && \
  dnf install -y --enablerepo=epel \
  xerces-c-devel

# These packages are needed for cloudberry-pxf
RUN  dnf install -y \
  maven \
  java-1.8.0-openjdk-devel \
  glibc-langpack-ru \
  glibc-locale-source

COPY ../configs/90-* /tmp/
COPY ../configs/gpinitsystem_singlenode /tmp/

RUN cp /tmp/90-cbdb-sysctl.conf /etc/sysctl.conf && \
  cp /tmp/90-cbdb-limits.conf /etc/security/limits.d/90-cbdb-limits.conf && \
  echo "mdw" > /tmp/gpdb-hosts && \
  echo "/usr/local/lib" >> /etc/ld.so.conf && \
  echo "/usr/local/lib64" >> /etc/ld.so.conf && \
  ldconfig && \
  chmod 777 /tmp/gpinitsystem_singlenode && \
  hostname > ~/orig_hostname && \
  /usr/sbin/groupadd gpadmin && \
  /usr/sbin/useradd  gpadmin -g gpadmin -G wheel && \
  setcap cap_net_raw+ep /usr/bin/ping && \
  echo "cbdb@123"|passwd --stdin gpadmin && \
  echo "gpadmin        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
  echo "root           ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers && \
  echo "export COORDINATOR_DATA_DIRECTORY=/data0/database/master/gpseg-1" >> /home/gpadmin/.bashrc && \
  echo "source /usr/local/cloudberry-db/greenplum_path.sh"                >> /home/gpadmin/.bashrc && \
  # echo "source /home/gpadmin/cloudberry/gpAux/gpdemo/gpdemo-env.sh"       >> /home/gpadmin/.bashrc && \
  mkdir -p /data0/database/master /data0/database/primary /data0/database/mirror && \
  chown -R gpadmin:gpadmin /data0 && \
  ssh-keygen -A && \
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# the following setup is needed for cloudberry-pxf
RUN \
  mkdir -p /home/gpadmin/workspace && chown gpadmin:gpadmin /home/gpadmin/workspace && \
  mkdir -p /etc/ssh/sshd_config.d && \
  touch /etc/ssh/sshd_config.d/pxf-automation.conf && \
  echo "KexAlgorithms +diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1" >> /etc/ssh/sshd_config.d/pxf-automation.conf && \
  echo "HostKeyAlgorithms +ssh-rsa,ssh-dss" >> /etc/ssh/sshd_config.d/pxf-automation.conf && \
  echo "PubkeyAcceptedAlgorithms +ssh-rsa,ssh-dss" >> /etc/ssh/sshd_config.d/pxf-automation.conf && \
  sudo update-crypto-policies --set LEGACY && \
  mkdir -p /usr/lib/locale/ru_RU.CP1251 && \
  localedef -f CP1251 -i ru_RU /usr/lib/locale/ru_RU.CP1251 && \
  alternatives --set java /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.452.b09-2.el9.aarch64/jre/bin/java

# Base system setup complete, switch to gpadmin to set up everything else
USER gpadmin

# ----------------------------------------------------------------------
# Configure passwordless SSH access for 'gpadmin' user
# ----------------------------------------------------------------------
# The script sets up SSH key-based authentication for the 'gpadmin' user,
# allowing passwordless SSH access. It generates a new SSH key pair if one
# does not already exist, and configures the necessary permissions.
# ----------------------------------------------------------------------
RUN \
  mkdir /home/gpadmin/.ssh && chown -R gpadmin:gpadmin /home/gpadmin/.ssh && \
  ssh-keygen -t rsa -b 4096 -m PEM -C gpadmin -f /home/gpadmin/.ssh/id_rsa -P "" && \
  cat /home/gpadmin/.ssh/id_rsa.pub >> /home/gpadmin/.ssh/authorized_keys && \
  chmod 0600 /home/gpadmin/.ssh/authorized_keys

RUN git clone --depth 1 --branch ${CODEBASE_VERSION_VAR} https://github.com/apache/cloudberry.git /home/gpadmin/cloudberry

WORKDIR /home/gpadmin/cloudberry

RUN   ./configure --prefix=/usr/local/cloudberry-db \
  --enable-cassert                  \
  --enable-debug-extensions         \
  --enable-ic-proxy                 \
  --enable-mapreduce                \
  --enable-orafce                   \
  --enable-orca                     \
  --enable-pxf                      \
  --enable-tap-tests                \
  --with-gssapi                     \
  --with-ldap                       \
  --with-libxml                     \
  --with-openssl                    \
  --with-pam                        \
  --with-perl                       \
  --with-pgport=5432                \
  --with-python                     \
  --with-pythonsrc-ext

RUN  make -j$(nproc) && sudo make install

WORKDIR /home/gpadmin/cloudberry/contrib

RUN  make -j$(nproc) && sudo make install

# Setup the Hadoop singlecluster
ENV GPHD_ROOT=/home/gpadmin/workspace/singlecluster
ENV HADOOP_ROOT=$GPHD_ROOT/hadoop
ENV HBASE_ROOT=$GPHD_ROOT/hbase
ENV HIVE_ROOT=$GPHD_ROOT/hive
ENV ZOOKEEPER_ROOT=$GPHD_ROOT/zookeeper
ENV PATH=$PATH:$GPHD_ROOT/bin:$HADOOP_ROOT/bin:$HBASE_ROOT/bin:$HIVE_ROOT/bin:$ZOOKEEPER_ROOT/bin

COPY ../configs/configure_singlecluster.bash /tmp/

RUN \
    wget http://storage.googleapis.com/pxf-public/singlecluster-HDP.tar.gz -O $HOME/workspace/singlecluster-HDP.tar.gz && \
    tar xf $HOME/workspace/singlecluster-HDP.tar.gz -C $HOME/workspace && \
    ln -s $HOME/workspace/singlecluster-HDP $HOME/workspace/singlecluster && \
    sudo chmod a+x /tmp/configure_singlecluster.bash && \
    /tmp/configure_singlecluster.bash

# add minio software
RUN sudo useradd -s /sbin/nologin -d /opt/minio minio \
    && sudo mkdir -p /opt/minio/bin \
    && sudo chmod a+rx /opt/minio \
    && sudo mkdir /opt/minio/data \
    && sudo wget -q https://dl.minio.io/server/minio/release/linux-amd64/minio -O /opt/minio/bin/minio \
    && sudo chmod +x /opt/minio/bin/minio \
    && sudo chown -R minio:minio /opt/minio \
    && sudo mkdir -p /opt/minio/data/gpdb-ud-scratch

#ENV MINIO_ACCESS_KEY=admin
#ENV MINIO_SECRET_KEY=password
#ENV ACCESS_KEY_ID=$MINIO_ACCESS_KEY
#ENV SECRET_ACCESS_KEY=$MINIO_SECRET_KEY

# ----------------------------------------------------------------------
# Set the Default User and Command
# ----------------------------------------------------------------------
# The default user is set to 'gpadmin', and the container starts by
# running the init_system.sh script. This container serves as a base
# environment, and the Cloudberry Database RPM can be installed for
# testing and functional verification.
# ----------------------------------------------------------------------
ENV USER=gpadmin
ENV JAVA_HOME=/etc/alternatives/java_sdk_1.8.0

# Set PXF environment variables (These could alternately be exported in ~gpadmin/bashrc)
ENV PXF_HOME=/usr/local/pxf
ENV PXF_BASE=/home/gpadmin/pxf
ENV PATH="$PXF_HOME/bin:$PATH"
ENV PXF_JVM_OPTS="-Xmx512m -Xms256m"
RUN sudo mkdir $PXF_HOME && sudo chown gpadmin:gpadmin $PXF_HOME

EXPOSE 5432 22

VOLUME [ "/sys/fs/cgroup", "/home/gpadmin/workspace/cloudberry-pxf" ]

COPY ../configs/init_system.sh /tmp/
RUN sudo chmod a+x /tmp/init_system.sh
CMD ["/bin/bash", "-c", "/tmp/init_system.sh" ]
