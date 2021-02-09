#############################################
FROM mosquito/fpm:centos7 as centos7

RUN yum upgrade -y
RUN yum install -y epel-release
RUN yum install -y gcc python-pip python-devel systemd-devel && yum clean all
RUN pip install -U "setuptools<40"
RUN yum install -y \
    python3-pip python3-devel
#############################################
FROM mosquito/fpm:debian9 as debian9

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev libsystemd-dev python3-dev \
    python3-setuptools python3-pkg-resources
RUN pip install -U setuptools
RUN pip3 install -U setuptools
#############################################
FROM mosquito/fpm:debian10 as debian10

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev \
    libsystemd-dev python3-dev python3-setuptools python3-pkg-resources
RUN pip install -U setuptools
RUN pip3 install -U setuptools
#############################################
FROM mosquito/fpm:xenial as xenial

RUN apt-get update && apt-get install -y \
    gcc python-pip python-dev libsystemd-dev
RUN pip install -U "setuptools<40"
#############################################
FROM mosquito/fpm:bionic as bionic

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev \
    libsystemd-dev python3-dev
RUN pip install -U "setuptools<40"
RUN pip3 install -U setuptools
#############################################
