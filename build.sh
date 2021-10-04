#!/bin/bash
#
# build.sh - purpose:  install Combine-Docker
#
#            calls:  buildstatic.sh
#

RUNDATE=`date +%Y-%m-%d_%H-%m-%S`

echo "Running Combine-Docker build script.  Note: this may take some time, anywhere from 5-20 minutes depending on your hardware."

# setup base directory for this build script
WORKDIR=$(pwd)

# source .env file to load config information that will probably change from release to release
source $WORKDIR/.env
echo "### BUILDLOG:  Base install directory (WORKDIR) is:  $WORKDIR"
sleep 1
# we will log output in output files in subdirectories named according to date-time of build run
if [ ! -d $WORKDIR/buildlogs ]
then
    mkdir $WORKDIR/buildlogs
fi
sleep 1
BUILDLOGDIR=$WORKDIR/buildlogs/build-log_$RUNDATE
mkdir $BUILDLOGDIR
BUILDLOG=$BUILDLOGDIR/build-log_$RUNDATE.log



# bring down Combine docker containers, if running
echo "### BUILDLOG:  Bringing down Docker containers (if they're running)"  | tee -a $BUILDLOG
docker-compose down 2>&1 | tee -a $BUILDLOG

# basic setup for nginx
touch $WORKDIR/nginx/error.log
if [[ ! -f "$WORKDIR/nginx/nginx.conf" ]]; then
  cp $WORKDIR/nginx/nginx.conf.template $WORKDIR/nginx/nginx.conf
fi

# init Combine app as a git submodule and use localsettings docker template
echo "Initializing Combine app submodule" 2>&1 | tee -a $BUILDLOG
#echo $COMBINE_BRANCH 2>&1 | tee -a $BUILDLOG
git submodule init   2>&1 | tee -a $BUILDLOG
git submodule update 2>&1 | tee -a $BUILDLOG

cd $WORKDIR/combine/combine 
git fetch 2>&1 | tee -a $BUILDLOG
git checkout $COMBINE_BRANCH 2>&1 | tee -a $BUILDLOG
##### git pull  # syntax incorrect; original intent unclear?

# the $WORKDIR/combine/combine/combine/localsettings.py and localsettings.py.docker
# files contain a variety of configuration settings for the Combine components
# (e.g. MySQL, AWS, DPLA API and site-specific settings, OAI metadata prefixes, 
# ElasticSearch Livy, Spark) and for the Combine application.  These should be
# updated according to local needs prior to using this in production.
if [[ ! -f "./combine/localsettings.py" ]]; then
    cp ./combine/localsettings.py.docker ./combine/localsettings.py
fi
sed -i 's/3306/3307/' ./combine/settings.py # mysql port is 3307 in docker, 3306 by default

if [[ ! -d "$WORKDIR/combine/combine/static/js/" ]]; then
  mkdir -p $WORKDIR/combine/combine/static/js/
fi
cd $WORKDIR


# build images
echo
echo 
echo "### BUILDLOG:  Removing existing Docker images" 2>&1 | tee -a $BUILDLOG
docker volume rm -f combine-docker_combine_python_env combine-docker_hadoop_binaries combine-docker_spark_binaries combine-docker_livy_binaries combine-docker_combine_tmp combine-docker_combinelib  | tee -a $BUILDLOG

echo  2>&1 | tee -a $BUILDLOG
echo "### BUILDLOG:  running docker-compose build in 2 seconds" 2>&1 | tee -a $BUILDLOG
sleep 2
docker-compose build 2>&1 >> $BUILDLOG
echo "### BUILDLOG:  finished running docker-compose build" 2>&1 | tee -a $BUILDLOG

# format Hadoop namenode
#####docker-compose run hadoop-namenode /bin/bash -c "mkdir -p /hdfs/namenode"
#####docker-compose run hadoop-namenode /bin/bash -c "echo 'Y' | /opt/hadoop/bin/hdfs namenode -format"

# Combine db migrations and superuser create
#####docker-compose run combine-django /bin/bash -c "bash /tmp/combine_db_prepare.sh"

#####. $WORKDIR/buildstatic.sh
