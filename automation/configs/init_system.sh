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
export GRADLE_OPTS="-Dfile.encoding=utf-8"
#pushd ~/workspace/cloudberry-pxf && make clean && make && make test && make install && popd
pushd ~/workspace/cloudberry-pxf && make install && popd

# Initialize singlecluster hadoop filesystem (needs to be done after PXF is installed)
cp $PXF_HOME/share/pxf-hbase-*.jar ~gpadmin/workspace/singlecluster/hbase/lib
init-gphd.sh
start-gphd.sh

pxf cluster prepare
# psql -P pager=off gpadmin -c 'CREATE EXTENSION pxf'
  #CREATE EXTENSION
# psql -P pager=off gpadmin -c 'DROP EXTENSION pxf'
  #DROP EXTENSION

# set up pxf configs from templates
cp -v $PXF_HOME/templates/{hdfs,mapred,yarn,core,hbase,hive}-site.xml $PXF_BASE/servers/default

# add file based stuff (breaks smoke tests because they put files in the wrong place)
#echo "create mount point and mount it"
#BASE_PATH=/mnt/nfs/var/nfsshare
#sudo mkdir -p ${BASE_PATH}
#sudo mount -t nfs cdw:/var/nfs ${BASE_PATH}
#sudo chown gpadmin:gpadmin ${BASE_PATH}
#sudo chmod 755 ${BASE_PATH}
#cp $PXF_HOME/templates/pxf-site.xml $PXF_BASE/servers/default/
#sed -i "s|</configuration>|<property><name>pxf.fs.basePath</name><value>${BASE_PATH}</value></property></configuration>|g" $PXF_BASE/servers/default/pxf-site.xml

#echo "Minio credentials: accessKey=${MINIO_ACCESS_KEY} secretKey=${MINIO_SECRET_KEY}"
#echo 'Starting Minio ...'
#MINIO_DOMAIN=localhost sudo /opt/minio/bin/minio server /opt/minio/data &
#
#mkdir -p $PXF_BASE/servers/minio
#sed -e "s|YOUR_AWS_ACCESS_KEY_ID|${ACCESS_KEY_ID}|" \
#	-e "s|YOUR_AWS_SECRET_ACCESS_KEY|${SECRET_ACCESS_KEY}|" \
#	-e "s|YOUR_MINIO_URL|http://localhost:9000|" \
#	$PXF_HOME/templates/minio-site.xml >$PXF_BASE/servers/minio/minio-site.xml
#
#MINIO_CORE_SITE_XML=$(mktemp)
#cat <<-EOF > "${MINIO_CORE_SITE_XML}"
#	<property>
#	  <name>fs.s3a.endpoint</name>
#	  <value>http://localhost:9000</value>
#	</property>
#	<property>
#	  <name>fs.s3a.access.key</name>
#	  <value>${ACCESS_KEY_ID}</value>
#	</property>
#	<property>
#	  <name>fs.s3a.secret.key</name>
#	  <value>${SECRET_ACCESS_KEY}</value>
#	</property>
#EOF
#sed -i -e "/<configuration>/r ${MINIO_CORE_SITE_XML}" ~gpadmin/workspace/singlecluster/hadoop/etc/hadoop/core-site.xml

# mkdir -p $PXF_BASE/servers/s3
# sed -e "s|YOUR_AWS_ACCESS_KEY_ID|DUMMY|" \
# 	-e "s|YOUR_AWS_SECRET_ACCESS_KEY|dummy|" \
# 	$PXF_HOME/templates/s3-site.xml >$PXF_BASE/servers/s3/s3-site.xml
#
# mkdir -p $PXF_BASE/servers/s3-invalid
# cp $PXF_HOME/templates/s3-site.xml $PXF_BASE/servers/s3-invalid/s3-site.xml
# chown -R gpadmin:gpadmin "$PXF_BASE/servers/s3" "$PXF_BASE/servers/s3-invalid"

# register the cluster
pxf cluster register

echo -e "\npxf.profile.dynamic.regex=test:.*" >> $PXF_BASE/conf/pxf-application.properties

pxf cluster start
# pxf cluster status
   #Checking status of PXF servers on coordinator host and 0 segment hosts...
   #PXF is running on 1 out of 1 host

echo """
===========================
=     BUILD SUCCESSFUL    =
===========================
"""

make GROUP=smoke -C $HOME/workspace/cloudberry-pxf/automation

# Uncomment to leave the container running for inspection
/bin/bash
