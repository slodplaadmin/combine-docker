source ./.env
WORKDIR=$(pwd)

echo "### BUILDLOG:  Creating static untar" 2>&1 | tee -a $BUILDLOG
cd $WORKDIR/combine/combine
if [[ ! -d "./static/" ]]; then
  mkdir static/
fi
tar -cf static.tar ./core/static/*
mv static.tar ./static
cd ./static
echo "### BUILDLOG:  Starting untar static.tar --strip=5" 2>&1 | tee -a $BUILDLOG
tar -xf static.tar --strip=5
echo "### BUILDLOG:  Starting untar static.tar --strip=4" 2>&1 | tee -a $BUILDLOG
tar -xf static.tar --strip=4
echo "### BUILDLOG:  Starting untar static.tar --strip=3" 2>&1 | tee -a $BUILDLOG
tar -xf static.tar --strip=3
echo "### BUILDLOG:  Starting untar static.tar --strip=2" 2>&1 | tee -a $BUILDLOG
tar -xf static.tar --strip=2
echo "### BUILDLOG:  Starting untar static.tar --strip=1" 2>&1 | tee -a $BUILDLOG
tar -xf static.tar --strip=1

if [[ ! -d "$WORKDIR/external-static/livy/" ]]; then
  mkdir -p $WORKDIR/external-static/livy
fi
cd $WORKDIR/external-static/livy

echo "### BUILDLOG:  svn export livy" 2>&1 | tee -a $BUILDLOG
svn export --force https://github.com/apache/incubator-livy/tags/$LIVY_TAGGED_RELEASE/server/src/main/resources/org/apache/livy/server/ui/static/js/

echo "### BUILDLOG:  svn export spark" 2>&1 | tee -a $BUILDLOG
if [[ ! -d "$WORKDIR/external-static/spark/" ]]; then
  mkdir -p $WORKDIR/external-static/spark
fi
cd $WORKDIR/external-static/spark
svn export --force https://github.com/apache/spark/tags/v$SPARK_VERSION/core/src/main/resources/org/apache/spark/ui/static
cd $WORKDIR

echo "### BUILDLOG:  creating external-static.tar" 2>&1 | tee -a $BUILDLOG
tar -cf external-static.tar ./external-static/*
mv external-static.tar $WORKDIR/combine/combine/static
cd $WORKDIR/combine/combine/static

echo "### BUILDLOG:  Starting external-static untar --strip=3" 2>&1 | tee -a $BUILDLOG
tar -xf external-static.tar --strip=3
echo "### BUILDLOG:  Starting external-static untar --strip=2" 2>&1 | tee -a $BUILDLOG
tar -xf external-static.tar --strip=2
echo "### BUILDLOG:  Starting external-static untar --strip=1" 2>&1 | tee -a $BUILDLOG
tar -xf external-static.tar --strip=1

cd $WORKDIR
echo "### BUILDLOG:  buildstatic.sh complete" 2>&1 | tee -a $BUILDLOG

