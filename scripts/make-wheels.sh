set -ex

SRC=/app/src
DST=/app/dst

yum install -y systemd-devel

function build_wheel() {
	/opt/python/$1/bin/pip wheel ${SRC} -f ${SRC} -w ${DST}
}


build_wheel cp35-cp35m
build_wheel cp36-cp36m
build_wheel cp37-cp37m
build_wheel cp38-cp38

cd ${DST}
for f in ./*linux_*; do if [ -f $f ]; then auditwheel repair $f -w . ; rm $f; fi; done
cd -

