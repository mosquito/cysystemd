CUR_DIR = $(shell pwd)
EPOCH = $(shell date +%s)

all: rpm_centos7 deb_debian8 deb_xenial deb_bionic

sdist:
	python setup.py sdist

images:
	docker build -t cysystemd:centos7 --target centos7 .
	docker build -t cysystemd:debian8 --target debian8 .
	docker build -t cysystemd:xenial --target xenial .
	docker build -t cysystemd:bionic --target bionic .

rpm_centos7: images sdist
	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python -d python-enum34 \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			-f -s python -t rpm /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python34u \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			--python-bin python3.4 --python-package-name-prefix python34u \
			-f -s python -t rpm /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python35u \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			--python-bin python3.5 --python-package-name-prefix python35u \
			-f -s python -t rpm /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python36u \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			--python-bin python3.6 --python-package-name-prefix python36u \
			-f -s python -t rpm /app

deb_debian8: images sdist
	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:debian8 \
		fpm --license "Apache 2" \
			-d libpython2.7 \
			-d libsystemd0 \
			-d python-enum34 \
			-d python-minimal \
			--iteration debian8 \
			--epoch $(EPOCH) \
			--python-install-lib /usr/lib/python2.7/dist-packages/ \
			-f -s python -t deb /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:debian8 \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d libpython3.4 \
			-d 'python3-minimal (>=3.4)' \
			--iteration debian8 \
			--epoch $(EPOCH) \
			--python-bin python3 --python-package-name-prefix python3 \
			--python-install-lib /usr/lib/python3.4/dist-packages/ \
			-f -s python -t deb /app

deb_xenial: images sdist
	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:xenial \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d python-minimal \
			-d python-enum34 \
			-d libpython2.7 \
			--python-install-lib /usr/lib/python2.7/dist-packages/ \
			--iteration xenial \
			--epoch $(EPOCH) \
			-f -s python -t deb /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:xenial \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d 'python3-minimal (>=3.4)' \
			-d libpython3.4 \
			--python-install-lib /usr/lib/python3.4/dist-packages/ \
			--python-bin python3 --python-package-name-prefix python3 \
			--iteration xenial \
			--epoch $(EPOCH) \
			-f -s python -t deb /app

deb_bionic: images sdist
	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:bionic \
		fpm --license "Apache 2" \
			-d libpython2.7 \
			-d libsystemd0 \
			-d python-minimal \
			-d python-enum34 \
			--python-install-lib /usr/lib/python2.7/dist-packages/ \
			--iteration bionic \
			--epoch $(EPOCH) \
			-f -s python -t deb /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:bionic \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d 'python3-minimal (>=3.6)' \
			-d libpython3.6 \
			--python-bin python3 --python-package-name-prefix python3 \
			--iteration bionic \
			--epoch $(EPOCH) \
			--python-install-lib /usr/lib/python3.6/dist-packages/ \
			-f -s python -t deb /app
