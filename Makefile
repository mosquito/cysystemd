CUR_DIR = $(shell pwd)
EPOCH = $(shell date +%s)

all: rpm_centos7 deb_debian deb_ubuntu linux_wheel

sdist:
	python setup.py sdist

linux_wheel:
	docker run -it --rm \
		--platform=linux/amd64 \
		-v $(shell pwd):/app/src \
		-v $(shell pwd)/dist:/app/dst \
		--entrypoint /bin/bash \
		quay.io/pypa/manylinux_2_28_x86_64 \
		/app/src/scripts/make-wheels.sh

	docker run -it --rm \
		-v $(shell pwd):/app/src \
		-v $(shell pwd)/dist:/app/dst \
		--platform=linux/arm64 \
		--entrypoint /bin/bash \
		quay.io/pypa/manylinux_2_28_aarch64 \
		/app/src/scripts/make-wheels.sh
