#!/bin/bash
#
# build.sh - purpose:  install Combine-Docker
#
#            calls:  buildstatic.sh
#



RUNDATE=`date +%Y-%m-%d_%H-%m-%S`

# setup base directory for this build script
WORKDIR=$(pwd)


# source .env file to load some config information; most will probably change from release to release:
#
#   COMBINE_BRANCH=v0.11.1
#   COMBINE_DJANGO_HOST_PORT=8000
#   COMBINE_DOCKER_VERSION=v0.11
#   ELASTICSEARCH_HADOOP_CONNECTOR_VERSION=7.1.1
#   HADOOP_VERSION=2.7.5
#   HADOOP_VERSION_SHORT=2.7
#   LIVY_TAGGED_RELEASE=v0.6.0-incubating
#   SCALA_VERSION=2.11
#   SPARK_VERSION=2.3.2
#   SPARK_GIT=branch-2.3
source $WORKDIR/.env


# override "COMBINE_BRANCH" version with dev value
COMBINE_BRANCH='update-installer'

# we will log output in output files in subdirectories named according to date-time of build run
if [ ! -d $WORKDIR/buildlogs ]
then
    mkdir $WORKDIR/buildlogs
fi
sleep 1
BUILDLOGDIR=$WORKDIR/buildlogs/build-log_$RUNDATE
mkdir $BUILDLOGDIR
BUILDLOG=$BUILDLOGDIR/build-log_$RUNDATE.log

echo ""
echo ""

echo "####################################################################################################"
echo "### BUILDLOG:  Running Combine-Docker build script. "
echo "### BUILDLOG:  Note: this may take some time, anywhere from 5-20 minutes depending on your hardware."
echo "### BUILDLOG"
echo "### BUILDLOG:  Base install directory (WORKDIR) is:  $WORKDIR" | tee -a $BUILDLOG
echo "### BUILDLOG:  " | tee -a $BUILDLOG
echo "### BUILDLOG:  see logs as they're created:  tail -f $BUILDLOG "
echo "### BUILDLOG:"
echo "### BUILDLOG:  hit ENTER to continue..."
read ANSWER
echo "### BUILDLOG:  Base install directory (WORKDIR) is:  $WORKDIR" | tee -a $BUILDLOG

# bring down Combine docker containers, if running
echo "### BUILDLOG:  Bringing down Docker containers (if they're running)"  | tee -a $BUILDLOG
docker-compose down 2>&1 | tee -a $BUILDLOG

# basic setup for nginx
touch $WORKDIR/nginx/error.log
if [[ ! -f "$WORKDIR/nginx/nginx.conf" ]]; then
  cp $WORKDIR/nginx/nginx.conf.template $WORKDIR/nginx/nginx.conf
fi

# init Combine app as a git submodule and use localsettings docker template
echo "### BUILDLOG:     Initializing Combine app submodule" 2>&1 | tee -a $BUILDLOG
echo "### BUILDLOG:     Working with Combine git branch:  $COMBINE_BRANCH" 2>&1 | tee -a $BUILDLOG
git submodule init   2>&1 | tee -a $BUILDLOG
git submodule update 2>&1 | tee -a $BUILDLOG

echo "### BUILDLOG:  Fetching desired Combine git branch" 2>&1 | tee -a $BUILDLOG
cd $WORKDIR/combine/combine 
git fetch 2>&1 | tee -a $BUILDLOG
git checkout $COMBINE_BRANCH 2>&1 | tee -a $BUILDLOG
git pull

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

echo "### BUILDLOG:  running docker-compose build...download can hang for several minutes" 2>&1 | tee -a $BUILDLOG
echo "### BUILDLOG:  start time:  `date`"  2>&1 | tee -a $BUILDLOG
docker-compose build  2>&1 >> $BUILDLOG
echo "### BUILDLOG:  finish time:  `date`"  2>&1 | tee -a $BUILDLOG
echo "### BUILDLOG:  finished running docker-compose build" 2>&1 | tee -a $BUILDLOG

# format Hadoop namenode
echo "### BUILDLOG:  formatting hadoop-namenode" 2>&1 | tee -a $BUILDLOG
docker-compose run hadoop-namenode /bin/bash -c "mkdir -p /hdfs/namenode" 1>>$BUILDLOG 2>&1
docker-compose run hadoop-namenode /bin/bash -c "echo 'Y' | /opt/hadoop/bin/hdfs namenode -format"  1>>$BUILDLOG 2>&1


# Combine db migrations and superuser create
echo "### BUILDLOG:  Combine db migrations and creation of superuser" 2>&1 | tee -a $BUILDLOG
docker-compose --log-level=warning run combine-django /bin/bash -c "bash /tmp/combine_db_prepare.sh" 2>&1 | tee -a $BUILDLOG

echo "### BUILDLOG:  Passing control to buildstatic.sh" 2>&1 | tee -a $BUILDLOG
. $WORKDIR/buildstatic.sh
