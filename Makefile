CUR_DIR = $(shell pwd)
EPOCH = $(shell date +%s)

all: rpm_centos7 deb_debian deb_ubuntu linux_wheel

sdist:
	python setup.py sdist

images:
	docker build -t cysystemd:centos7 --target centos7 .
	docker build -t cysystemd:debian9 --target debian9 .
	docker build -t cysystemd:debian10 --target debian10 .
	docker build -t cysystemd:xenial --target xenial .
	docker build -t cysystemd:bionic --target bionic .

rpm_centos7: images sdist
	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			--python-bin python2 --python-package-name-prefix python \
			-f -s python -t rpm /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:centos7 \
		fpm --license "Apache 2" -d systemd-libs -d python3 \
			--rpm-dist centos7 \
			--epoch $(EPOCH) \
			--python-bin python3.6 --python-package-name-prefix python3 \
			-f -s python -t rpm /app

deb_debian: deb_debian10 deb_debian9

deb_debian9: images sdist
	docker run -i --rm \
    		-v $(CUR_DIR):/app \
    		--workdir /app/dist \
    		cysystemd:debian9 \
    		fpm --license "Apache 2" \
    			-d libpython2.7 \
    			-d libsystemd0 \
    			-d python-enum34 \
    			-d python-minimal \
    			--iteration debian9 \
    			--epoch $(EPOCH) \
    			--python-install-lib /usr/lib/python2.7/dist-packages/ \
    			-f -s python -t deb /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:debian9 \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d libpython3.4 \
			-d 'python3-minimal (>=3.4)' \
			--iteration debian9 \
			--epoch $(EPOCH) \
			--python-bin python3 --python-package-name-prefix python3 \
			--python-install-lib /usr/lib/python3.4/dist-packages/ \
			-f -s python -t deb /app

deb_debian10: images sdist
	docker run -i --rm \
        		-v $(CUR_DIR):/app \
        		--workdir /app/dist \
        		cysystemd:debian10 \
        		fpm --license "Apache 2" \
        			-d libpython2.7 \
        			-d libsystemd0 \
        			-d python-enum34 \
        			-d python-minimal \
        			--iteration debian10 \
        			--epoch $(EPOCH) \
        			--python-install-lib /usr/lib/python2.7/dist-packages/ \
        			-f -s python -t deb /app

	docker run -i --rm \
		-v $(CUR_DIR):/app \
		--workdir /app/dist \
		cysystemd:debian10 \
		fpm --license "Apache 2" \
			-d libsystemd0 \
			-d libpython3.4 \
			-d 'python3-minimal (>=3.4)' \
			--iteration debian10 \
			--epoch $(EPOCH) \
			--python-bin python3 --python-package-name-prefix python3 \
			--python-install-lib /usr/lib/python3.4/dist-packages/ \
			-f -s python -t deb /app

deb_ubuntu: deb_xenial deb_bionic

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

linux_wheel:
	docker run -it --rm \
		-v `pwd`:/app/src:ro \
		-v `pwd`/dist:/app/dst \
		--entrypoint /bin/bash \
		quay.io/pypa/manylinux2014_x86_64 \
		/app/src/scripts/make-wheels.sh
