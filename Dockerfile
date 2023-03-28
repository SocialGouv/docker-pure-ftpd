#Stage 1 : builder debian image
FROM debian:buster as builder

# feel free to change this ;)
LABEL maintainer "SocialGouv"

# properly setup debian sources
ENV DEBIAN_FRONTEND noninteractive
RUN echo "deb http://http.debian.net/debian buster main\n\
deb-src http://http.debian.net/debian buster main\n\
deb http://http.debian.net/debian buster-updates main\n\
deb-src http://http.debian.net/debian buster-updates main\n\
deb http://security.debian.org buster/updates main\n\
deb-src http://security.debian.org buster/updates main\n\
" > /etc/apt/sources.list

# install package building helpers
RUN apt-get -y update && \
	apt-get -y --fix-missing install dpkg-dev debhelper &&\
	apt-get -y build-dep pure-ftpd

# Build from source - we need to remove the need for CAP_SYS_NICE and CAP_DAC_READ_SEARCH
ARG LANGUAGE=french
RUN mkdir /tmp/pure-ftpd/ && \
	cd /tmp/pure-ftpd/ && \
	apt-get source pure-ftpd && \
	cd pure-ftpd-* && \
	./configure \
		--with-tls \
		--with-nonroot \
		--with-everything \
		--with-language=${LANGUAGE} \
		--prefix=/pureftpd && \
		make install-strip

FROM debian:buster-slim

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && \
	apt-get  --no-install-recommends --yes install \
	libc6 \
	libcap2 \
	libmariadb3 \
	libpam0g \
	libssl1.1 \
	lsb-base \
	openbsd-inetd \
	openssl \
	perl

# setup ftpgroup and ftpuser
RUN groupadd -g 1001 ftpgroup &&\
	useradd -g ftpgroup --create-home -d /home/ftpusers -s /bin/sh -u 1001 ftpuser

COPY --from=builder --chown=1001:1001 /pureftpd /pureftpd

# prevent pure-ftpd upgrading
RUN apt-mark hold pure-ftpd pure-ftpd-common

# setup rootless
RUN chown -R ftpuser:ftpgroup /etc/ssl/private && \
	chown -R ftpuser:ftpgroup /var/log

# default publichost, you'll need to set this for passive support
ENV PUBLICHOST localhost

# startup
CMD /run.sh \
	-l puredb:/pureftpd/etc/pureftpd.pdb \
	-E \
	-j \
	-R \
	-F /pureftpd/banner.txt \
	-O clf:/var/log/pureftpd.log \
	-P $PUBLICHOST

EXPOSE 2121 30000-30009

# setup rootless
USER 1001
WORKDIR /home/ftpusers

# setup run/init file
COPY run.sh /run.sh
ARG BANNER="---------- Welcome to Pure-FTPd [privsep] [TLS] ----------"
RUN echo ${BANNER}>/pureftpd/banner.txt