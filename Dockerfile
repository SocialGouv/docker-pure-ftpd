#Stage 1 : builder debian image
FROM debian:buster as builder

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
# rsyslog for logging (ref https://github.com/stilliard/docker-pure-ftpd/issues/17)
RUN apt-get -y update && \
	apt-get -y --force-yes --fix-missing install dpkg-dev debhelper &&\
	apt-get -y build-dep pure-ftpd

# install dependencies
# FIXME : libcap2 is not a dependency anymore. .deb could be fixed to avoid asking this dependency
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
    perl \
	rsyslog
	
# setup ftpgroup and ftpuser
RUN groupadd -g 1001 ftpgroup &&\
	useradd -g ftpgroup --create-home -d /home/ftpusers -s /bin/sh -u 1001 ftpuser

USER 1001

# Build from source - we need to remove the need for CAP_SYS_NICE and CAP_DAC_READ_SEARCH
RUN mkdir /tmp/pure-ftpd/ && \
	cd /tmp/pure-ftpd/ && \
	apt-get source pure-ftpd && \
	cd pure-ftpd-* && \
	./configure --with-tls --with-nonroot --with-everything --prefix=/home/ftpusers && make install-strip

# feel free to change this ;)
LABEL maintainer "SocialGouv"


USER 0
# prevent pure-ftpd upgrading
RUN apt-mark hold pure-ftpd pure-ftpd-common


# configure rsyslog logging
RUN echo "" >> /etc/rsyslog.conf && \
	echo "#PureFTP Custom Logging" >> /etc/rsyslog.conf && \
	echo "ftp.* /var/log/pure-ftpd/pureftpd.log" >> /etc/rsyslog.conf && \
	echo "Updated /etc/rsyslog.conf with /var/log/pure-ftpd/pureftpd.log"

# create passwd dir
RUN mkdir -p /etc/pure-ftpd/passwd

# setup rootless
RUN chown -R ftpuser:ftpgroup /etc/ssl/private/ \
	&& touch /etc/pure-ftpd/passwd/pureftpd.passwd \
	&& chown -R ftpuser:ftpgroup /etc/pure-ftpd \
	&& chown -R ftpuser:ftpgroup /home

# default publichost, you'll need to set this for passive support
ENV PUBLICHOST localhost

# startup
CMD /run.sh -l puredb:/etc/pure-ftpd/pureftpd.pdb -E -j -R -P $PUBLICHOST

EXPOSE 2121 30000-30009

# setup rootless
USER 1001
WORKDIR /home/ftpusers

# setup run/init file
COPY run.sh /run.sh