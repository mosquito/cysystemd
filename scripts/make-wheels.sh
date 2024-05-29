set -ex

SRC=/app/src
DST=/app/dst

cd ${SRC}
VERSION=`/opt/python/cp311-cp311/bin/python setup.py --version`
ARCH=`/opt/python/cp311-cp311/bin/python -c 'import platform; print(platform.machine())'`
cd -

function build_wheel() {
  /opt/python/$1/bin/pip install -U Cython
	/opt/python/$1/bin/pip wheel ${SRC} -f ${SRC} -w ${DST}
}

yum install -y systemd-devel

build_wheel cp38-cp38
build_wheel cp39-cp39
build_wheel cp310-cp310
build_wheel cp311-cp311
build_wheel cp312-cp312

echo ${VERSION}*linux_${ARCH}

cd ${DST}
for f in ./*${VERSION}*linux_${ARCH}*
do
  if [ -f $f ]
  then auditwheel repair $f -w .
  rm $f
  fi
done

cd -
