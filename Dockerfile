FROM debian:buster as builder

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

RUN apt-get -y update && \
	apt-get -y --fix-missing install dpkg-dev debhelper &&\
	apt-get -y build-dep pure-ftpd

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
	perl && \
		rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1001 ftpgroup &&\
	useradd -g ftpgroup --create-home -d /home/ftpusers -s /bin/sh -u 1001 ftpuser

COPY --from=builder --chown=1001:1001 /pureftpd /pureftpd

RUN apt-mark hold pure-ftpd pure-ftpd-common

RUN chown -R ftpuser:ftpgroup /etc/ssl/private && \
	chown -R ftpuser:ftpgroup /var/log

ENV PUBLICHOST localhost

CMD /run.sh \
	-l puredb:/pureftpd/etc/pureftpd.pdb \
	-E \
	-j \
	-R \
	-F /pureftpd/banner.txt \
	-O clf:/var/log/pureftpd.log \
	-P $PUBLICHOST

EXPOSE 2121 30000-30009

USER 1001
WORKDIR /home/ftpusers

COPY run.sh /run.sh
ARG WELCOME_BANNER="---------- Welcome to Pure-FTPd [privsep] [TLS] ----------"
ENV WELCOME_BANNER=${WELCOME_BANNER}