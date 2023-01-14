# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# For this Dockerfile to run just provide a private key named cert.key.pem
# and a fullchain named cert.pem in the directory wich will be passed
# to the docker damon
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

FROM centos:centos8

MAINTAINER Armin Kunkel <armin@avensio.de>

LABEL vendor=avensio \
  de.avensio.nexus.name="Nexus Repository Manager image with ssl only support"

# ARGS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ARG SSL_STOREPASS=changeit
ARG NEXUS_VERSION=3.37.3-02
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_HASH_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz.sha1
ARG NEXUS_CONTEXT_PATH='/'
ARG Xms=2048m
ARG Xmx=2048m
ARG MDMS=2g

# set nexus home
ENV NEXUS_HOME=/opt/nexus/nexus-${NEXUS_VERSION}

# set nexus data
ENV NEXUS_DATA=/nexus-data \
  SONATYPE_WORK=${NEXUS_HOME}/../sonatype-work \
  SSL_WORK=${NEXUS_HOME}/etc/ssl

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
RUN yum update -y
# install curl and tar
RUN yum install -y curl tar && yum clean all
# install openssl
RUN yum install -y openssl

# copy tls private key and fullchain certificate
COPY cert.key.pem ${SSL_WORK}/cert.key.pem
COPY cert.pem ${SSL_WORK}/cert.pem

# install JRE
RUN yum install -y java-1.8.0-openjdk

# add user nexus
RUN useradd -r -u 200 -m -c "nexus role account" -d ${NEXUS_DATA} -s /bin/false nexus

# downlaod nexus and verify hash. Then install nexus
RUN mkdir -p /opt/nexus \
    && curl --fail --silent --location --retry 3 ${NEXUS_DOWNLOAD_URL} --output nexus-${NEXUS_VERSION}.tar.gz
RUN curl --fail --silent --location --retry 3 ${NEXUS_DOWNLOAD_HASH_URL} --output nexus-${NEXUS_VERSION}.tar.gz.sha1
RUN sed -i 's/$/\ \ nexus-'$NEXUS_VERSION'\.tar\.gz/' nexus-${NEXUS_VERSION}.tar.gz.sha1
RUN cat nexus-${NEXUS_VERSION}.tar.gz.sha1
RUN sha1sum -c nexus-${NEXUS_VERSION}.tar.gz.sha1
RUN tar xf nexus-${NEXUS_VERSION}.tar.gz -C ${NEXUS_HOME} --strip-components=1 nexus-${NEXUS_VERSION} \
  && chown -R nexus:nexus ${NEXUS_HOME}/..

# configure nexus and enable TLS
RUN sed \
    -e "s|nexus-context-path=.*|nexus-context-path=${NEXUS_CONTEXT_PATH}|" \
    -e '/nexus-args=/ s/=.*/=${jetty.etc}\/jetty.xml,${jetty.etc}\/jetty-https.xml,${jetty.etc}\/jetty-requestlog.xml/' \
    -i ${NEXUS_HOME}/etc/nexus-default.properties \
  && echo 'ssl.etc=${karaf.data}/etc/ssl' >> ${NEXUS_HOME}/etc/nexus-default.properties \
  && echo "application-port-ssl=8443" >> ${NEXUS_HOME}/etc/nexus-default.properties

# configure jetty TLS support
RUN sed \
    -e 's/<Set name="KeyStorePath">.*<\/Set>/<Set name="KeyStorePath">\/opt\/nexus\/nexus-'$NEXUS_VERSION'\/etc\/ssl\/server-keystore.jks<\/Set>/g' \
    -e 's/<Set name="KeyStorePassword">.*<\/Set>/<Set name="KeyStorePassword">'"${SSL_STOREPASS}"'<\/Set>/g' \
    -e 's/<Set name="KeyManagerPassword">.*<\/Set>/<Set name="KeyManagerPassword">'"${SSL_STOREPASS}"'<\/Set>/g' \
    -e 's/<Set name="TrustStorePath">.*<\/Set>/<Set name="TrustStorePath">\/opt\/nexus\/nexus-'$NEXUS_VERSION'\/etc\/ssl\/server-keystore.jks<\/Set>/g' \
    -e 's/<Set name="TrustStorePassword">.*<\/Set>/<Set name="TrustStorePassword">'"${SSL_STOREPASS}"'<\/Set>/g' \
    -e 's|<Item>TLSv1.2</Item>|<Item>TLSv1.2</Item>\n<Item>TLSv1.3</Item>|' \
    -i ${NEXUS_HOME}/etc/jetty/jetty-https.xml

# generate pkcs12 file
RUN openssl pkcs12 -export \
  -inkey ${SSL_WORK}/cert.key.pem \
  -in ${SSL_WORK}/cert.pem \
  -out ${SSL_WORK}/jetty.pkcs12 \
  -passout pass:${SSL_STOREPASS}

# generate keystore
RUN ${JAVA_HOME}/bin/keytool -importkeystore -noprompt \
  -srckeystore ${SSL_WORK}/jetty.pkcs12 \
  -srcstoretype PKCS12 \
  -srcstorepass ${SSL_STOREPASS} \
  -deststorepass ${SSL_STOREPASS} \
  -destkeystore ${SSL_WORK}/server-keystore.jks

RUN mkdir -p ${NEXUS_DATA}/etc ${NEXUS_DATA}/log ${NEXUS_DATA}/tmp ${SONATYPE_WORK} \
  && ln -s ${NEXUS_DATA} ${SONATYPE_WORK}/nexus3 \
  && chown -R nexus:nexus ${NEXUS_DATA}

VOLUME ${NEXUS_DATA}
EXPOSE 8081 8082 8083 8084 8443
USER nexus
WORKDIR ${NEXUS_HOME}

ENV INSTALL4J_JAVA_HOME=/usr/lib/jvm/
ENV INSTALL4J_ADD_VM_PARAMS="-Xms${Xms} -Xmx${Xmx} -XX:MaxDirectMemorySize=${MDMS} -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["bin/nexus", "run"]
