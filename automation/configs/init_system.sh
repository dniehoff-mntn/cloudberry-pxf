#!/bin/bash
## ======================================================================
## Container initialization script
## ======================================================================

# ----------------------------------------------------------------------
# Start SSH daemon and setup for SSH access
# ----------------------------------------------------------------------
# The SSH daemon is started to allow remote access to the container via
# SSH. This is useful for development and debugging purposes. If the SSH
# daemon fails to start, the script exits with an error.
# ----------------------------------------------------------------------
if ! sudo /usr/sbin/sshd; then
    echo "Failed to start SSH daemon" >&2
    exit 1
fi

# ----------------------------------------------------------------------
# Remove /run/nologin to allow logins
# ----------------------------------------------------------------------
# The /run/nologin file, if present, prevents users from logging into
# the system. This file is removed to ensure that users can log in via SSH.
# ----------------------------------------------------------------------
sudo rm -rf /run/nologin

# ## Set gpadmin ownership - Clouberry install directory and supporting
# ## cluster creation files.
sudo chown -R gpadmin.gpadmin /usr/local/cloudberry-db \
                              /tmp/gpinitsystem_singlenode \
                              /tmp/gpdb-hosts

# Source Cloudberry environment variables and set
# COORDINATOR_DATA_DIRECTORY
ssh-keyscan -t rsa mdw > /home/gpadmin/.ssh/known_hosts 2>/dev/null
source /usr/local/cloudberry-db/greenplum_path.sh
export COORDINATOR_DATA_DIRECTORY=/data0/database/master/gpseg-1

# Initialize single node Cloudberry cluster
gpinitsystem -a \
             -c /tmp/gpinitsystem_singlenode \
             -h /tmp/gpdb-hosts \
             --max_connections=100

# Initialize singlecluster hadoop filesystem
init-gphd.sh
start-gphd.sh

## Allow any host access the Cloudberry Cluster
echo 'host all all 0.0.0.0/0 trust' >> /data0/database/master/gpseg-1/pg_hba.conf
gpstop -u

psql -d template1 \
     -c "ALTER USER gpadmin PASSWORD 'cbdb@123'"

cat <<-'EOF'

======================================================================
  ____ _                 _ _                            ____  ____
 / ___| | ___  _   _  __| | |__   ___ _ __ _ __ _   _  |  _ \| __ )
| |   | |/ _ \| | | |/ _` | '_ \ / _ \ '__| '__| | | | | | | |  _ \
| |___| | (_) | |_| | (_| | |_) |  __/ |  | |  | |_| | | |_| | |_) |
 \____|_|\___/ \__,_|\__,_|_.__/ \___|_|  |_|   \__, | |____/|____/
                                                |___/
======================================================================
EOF

cat <<-'EOF'

======================================================================
Testing: Cloudberry Database Cluster details
======================================================================

EOF

echo "Current time: $(date)"
source /etc/os-release
echo "OS Version: ${NAME} ${VERSION}"

## Set gpadmin password, display version and cluster configuration
psql -P pager=off -d template1 -c "SELECT VERSION()"
psql -P pager=off -d template1 -c "SELECT * FROM gp_segment_configuration ORDER BY dbid"
psql -P pager=off -d template1 -c "SHOW optimizer"

echo """
===========================
=  DEPLOYMENT SUCCESSFUL  =
===========================
"""

# POST startup commands
# TODO: can check the output of the commented commands to make sure things are running
pushd ~/workspace/cloudberry-pxf && make && make test && make install && popd
pxf cluster prepare
# psql -P pager=off gpadmin -c 'CREATE EXTENSION pxf'
  #CREATE EXTENSION
# psql -P pager=off gpadmin -c 'DROP EXTENSION pxf'
  #DROP EXTENSION
cp -v $PXF_HOME/templates/{hdfs,mapred,yarn,core,hbase,hive}-site.xml $PXF_BASE/servers/default
pxf cluster register
pxf cluster start
# pxf cluster status
   #Checking status of PXF servers on coordinator host and 0 segment hosts...
   #PXF is running on 1 out of 1 host

echo """
===========================
=     BUILD SUCCESSFUL    =
===========================
"""

# make TEST=HdfsSmokeTest -C $HOME/workspace/cloudberry-pxf/automation
make GROUP=gpdb -C $HOME/workspace/cloudberry-pxf/automation

# Uncomment to leave the container running for inspection
/bin/bash
