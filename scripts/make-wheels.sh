set -ex

SRC=/app/src
DST=/app/dst

function build_wheel() {
	/opt/python/$1/bin/pip wheel ${SRC} -f ${SRC} -w ${DST}
}

build_wheel cp37-cp37m
build_wheel cp38-cp38
build_wheel cp39-cp39
build_wheel cp310-cp310
build_wheel cp311-cp311

cd ${DST}
for f in ./*linux_*; do if [ -f $f ]; then auditwheel repair $f -w . ; rm $f; fi; done
cd -

