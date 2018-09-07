#############################################
FROM mosquito/fpm:centos7 as centos7

RUN yum install -y epel-release
RUN yum install -y gcc python-pip python-devel systemd-devel && yum clean all
RUN pip install -U setuptools
RUN yum localinstall -y https://centos7.iuscommunity.org/ius-release.rpm
RUN yum install -y \
    python34u-pip python34u-devel \
    python35u-pip python35u-devel \
    python36u-pip python36u-devel
#############################################
FROM mosquito/fpm:debian8 as debian8

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev \
    libsystemd-dev python3-dev
RUN pip install -U setuptools
RUN pip3 install -U setuptools
#############################################
FROM mosquito/fpm:xenial as xenial

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev \
    libsystemd-dev python3-dev
RUN pip install -U setuptools
RUN pip3 install -U setuptools
#############################################
FROM mosquito/fpm:bionic as bionic

RUN apt-get update && apt-get install -y \
    gcc python-pip python3-pip python-dev \
    libsystemd-dev python3-dev
RUN pip install -U setuptools
RUN pip3 install -U setuptools
#############################################
