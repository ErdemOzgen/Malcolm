FROM debian:11-slim AS build

# Copyright (c) 2022 Battelle Energy Alliance, LLC.  All rights reserved.

ENV DEBIAN_FRONTEND noninteractive

ENV ARKIME_VERSION "3.4.2"
ENV ARKIMEDIR "/opt/arkime"
ENV ARKIME_URL "https://github.com/arkime/arkime.git"
ENV ARKIME_LOCALELASTICSEARCH no
ENV ARKIME_INET yes

ADD arkime/scripts/bs4_remove_div.py /opt/
ADD arkime/patch/* /opt/patches/
ADD README.md $ARKIMEDIR/doc/
ADD docs/doc.css $ARKIMEDIR/doc/
ADD docs/images $ARKIMEDIR/doc/images/

RUN apt-get -q update && \
    apt-get -y -q --no-install-recommends upgrade && \
    apt-get install -q -y --no-install-recommends \
        binutils \
        bison \
        cmake \
        curl \
        file \
        flex \
        g++ \
        gcc \
        gettext \
        git-core \
        groff \
        groff-base \
        imagemagick \
        libcap-dev \
        libjson-perl \
        libkrb5-dev \
        libmaxminddb-dev \
        libpcap0.8-dev \
        libssl-dev \
        libtool \
        libwww-perl \
        libyaml-dev \
        make \
        meson \
        ninja-build \
        pandoc \
        patch \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        rename \
        sudo \
        swig \
        wget \
        zlib1g-dev && \
  pip3 install --no-cache-dir beautifulsoup4 && \
  cd $ARKIMEDIR/doc/images && \
    find . -name "*.png" -exec bash -c 'convert "{}" -fuzz 2% -transparent white -background white -alpha remove -strip -interlace Plane -quality 85% "{}.jpg" && rename "s/\.png//" "{}.jpg"' \; && \
    cd $ARKIMEDIR/doc && \
    sed -i "s/^# Malcolm$//" README.md && \
    sed -i '/./,$!d' README.md && \
    sed -i "s/.png/.jpg/g" README.md && \
    sed -i "s@docs/images@images@g" README.md && \
    sed -i 's/\!\[.*\](.*\/badge.svg)//g' README.md && \
    pandoc -s --self-contained --metadata title="Malcolm README" --css $ARKIMEDIR/doc/doc.css -o $ARKIMEDIR/doc/README.html $ARKIMEDIR/doc/README.md && \
  cd /opt && \
    git clone --depth=1 --single-branch --recurse-submodules --shallow-submodules --no-tags --branch="v$ARKIME_VERSION" "$ARKIME_URL" "./arkime-"$ARKIME_VERSION && \
    cd "./arkime-"$ARKIME_VERSION && \
    bash -c 'for i in /opt/patches/*; do patch -p 1 -r - --no-backup-if-mismatch < $i || true; done' && \
    find $ARKIMEDIR/doc/images/screenshots -name "*.png" -delete && \
    export PATH="$ARKIMEDIR/bin:${PATH}" && \
    ln -sfr $ARKIMEDIR/bin/npm /usr/local/bin/npm && \
    ln -sfr $ARKIMEDIR/bin/node /usr/local/bin/node && \
    ln -sfr $ARKIMEDIR/bin/npx /usr/local/bin/npx && \
    python3 /opt/bs4_remove_div.py -i ./viewer/vueapp/src/components/users/Users.vue -o ./viewer/vueapp/src/components/users/Users.new -c "new-user-form" && \
    mv -vf ./viewer/vueapp/src/components/users/Users.new ./viewer/vueapp/src/components/users/Users.vue && \
    sed -i 's/v-if.*password.*"/v-if="false"/g' ./viewer/vueapp/src/components/settings/Settings.vue && \
    rm -rf ./viewer/vueapp/src/components/upload ./capture/plugins/suricata* && \
    sed -i "s/^\(ARKIME_LOCALELASTICSEARCH=\).*/\1"$ARKIME_LOCALELASTICSEARCH"/" ./release/Configure && \
    sed -i "s/^\(ARKIME_INET=\).*/\1"$ARKIME_INET"/" ./release/Configure && \
    ./easybutton-build.sh && \
    npm -g config set user root && \
    make install && \
    npm cache clean --force && \
    rm -f ${ARKIMEDIR}/wiseService/source.* && \
    bash -c "file ${ARKIMEDIR}/bin/* ${ARKIMEDIR}/node-v*/bin/* | grep 'ELF 64-bit' | sed 's/:.*//' | xargs -l -r strip -v --strip-unneeded"

FROM debian:11-slim

LABEL maintainer="malcolm@inl.gov"
LABEL org.opencontainers.image.authors='malcolm@inl.gov'
LABEL org.opencontainers.image.url='https://github.com/cisagov/Malcolm'
LABEL org.opencontainers.image.documentation='https://github.com/cisagov/Malcolm/blob/main/README.md'
LABEL org.opencontainers.image.source='https://github.com/cisagov/Malcolm'
LABEL org.opencontainers.image.vendor='Cybersecurity and Infrastructure Security Agency'
LABEL org.opencontainers.image.title='malcolmnetsec/arkime'
LABEL org.opencontainers.image.description='Malcolm container providing Arkime'

ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ENV DEFAULT_UID $DEFAULT_UID
ENV DEFAULT_GID $DEFAULT_GID
ENV PUSER "arkime"
ENV PGROUP "arkime"
ENV PUSER_PRIV_DROP true

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

ARG OS_HOST=opensearch
ARG OS_PORT=9200
ARG MALCOLM_USERNAME=admin
ARG ARKIME_ECS_PROVIDER=arkime
ARG ARKIME_ECS_DATASET=session
ARG ARKIME_INTERFACE=eth0
ARG ARKIME_ANALYZE_PCAP_THREADS=1
ARG WISE=off
ARG VIEWER=on
#Whether or not Arkime is in charge of deleting old PCAP files to reclaim space
ARG MANAGE_PCAP_FILES=false
#Whether or not to auto-tag logs based on filename
ARG AUTO_TAG=true
ARG PCAP_PIPELINE_DEBUG=false
ARG PCAP_PIPELINE_DEBUG_EXTRA=false
ARG PCAP_MONITOR_HOST=pcap-monitor
ARG MAXMIND_GEOIP_DB_LICENSE_KEY=""

# Declare envs vars for each arg
ENV OS_HOST $OS_HOST
ENV OS_PORT $OS_PORT
ENV ARKIME_ELASTICSEARCH "http://"$OS_HOST":"$OS_PORT
ENV ARKIME_INTERFACE $ARKIME_INTERFACE
ENV MALCOLM_USERNAME $MALCOLM_USERNAME
# this needs to be present, but is unused as nginx is going to handle auth for us
ENV ARKIME_PASSWORD "ignored"
ENV ARKIME_ECS_PROVIDER $ARKIME_ECS_PROVIDER
ENV ARKIME_ECS_DATASET $ARKIME_ECS_DATASET
ENV ARKIMEDIR "/opt/arkime"
ENV ARKIME_ANALYZE_PCAP_THREADS $ARKIME_ANALYZE_PCAP_THREADS
ENV WISE $WISE
ENV VIEWER $VIEWER
ENV MANAGE_PCAP_FILES $MANAGE_PCAP_FILES
ENV AUTO_TAG $AUTO_TAG
ENV PCAP_PIPELINE_DEBUG $PCAP_PIPELINE_DEBUG
ENV PCAP_PIPELINE_DEBUG_EXTRA $PCAP_PIPELINE_DEBUG_EXTRA
ENV PCAP_MONITOR_HOST $PCAP_MONITOR_HOST

COPY --from=build $ARKIMEDIR $ARKIMEDIR

RUN sed -i "s/bullseye main/bullseye main contrib non-free/g" /etc/apt/sources.list && \
    apt-get -q update && \
    apt-get -y -q --no-install-recommends upgrade && \
    apt-get install -q -y --no-install-recommends \
      curl \
      file \
      geoip-bin \
      gettext \
      libcap2-bin \
      libjson-perl \
      libkrb5-3 \
      libmaxminddb0 \
      libpcap0.8 \
      libssl1.0 \
      libtool \
      libwww-perl \
      libyaml-0-2 \
      libzmq5 \
      procps \
      psmisc \
      python \
      python3 \
      python3-pip \
      python3-setuptools \
      python3-wheel \
      rename \
      sudo \
      supervisor \
      vim-tiny \
      wget \
      tar gzip unzip cpio bzip2 lzma xz-utils p7zip-full unrar zlib1g && \
    pip3 install --no-cache-dir beautifulsoup4 pyzmq && \
    ln -sfr $ARKIMEDIR/bin/npm /usr/local/bin/npm && \
      ln -sfr $ARKIMEDIR/bin/node /usr/local/bin/node && \
      ln -sfr $ARKIMEDIR/bin/npx /usr/local/bin/npx && \
    apt-get -q -y --purge remove gcc gcc-10 cpp cpp-10 libssl-dev && \
      apt-get -q -y autoremove && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add configuration and scripts
ADD shared/bin/docker-uid-gid-setup.sh /usr/local/bin/
ADD arkime/scripts /opt/
ADD shared/bin/pcap_processor.py /opt/
ADD shared/bin/pcap_utils.py /opt/
ADD shared/bin/opensearch_status.sh /opt/
ADD arkime/etc $ARKIMEDIR/etc/
ADD arkime/wise/source.*.js $ARKIMEDIR/wiseService/
ADD arkime/supervisord.conf /etc/supervisord.conf

# MaxMind now requires a (free) license key to download the free versions of
# their GeoIP databases. This should be provided as a build argument.
#   see https://dev.maxmind.com/geoip/geoipupdate/#Direct_Downloads
#   see https://github.com/arkime/arkime/issues/1350
#   see https://github.com/arkime/arkime/issues/1352
RUN [ ${#MAXMIND_GEOIP_DB_LICENSE_KEY} -gt 1 ] && for DB in ASN Country City; do \
      cd /tmp && \
      curl -s -S -L -o "GeoLite2-$DB.mmdb.tar.gz" "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-$DB&license_key=$MAXMIND_GEOIP_DB_LICENSE_KEY&suffix=tar.gz" && \
      tar xf "GeoLite2-$DB.mmdb.tar.gz" --wildcards --no-anchored '*.mmdb' --strip=1 && \
      mkdir -p $ARKIMEDIR/etc/ $ARKIMEDIR/logs/ && \
      mv -v "GeoLite2-$DB.mmdb" $ARKIMEDIR/etc/; \
      rm -f "GeoLite2-$DB*"; \
    done; \
  curl -s -S -L -o $ARKIMEDIR/etc/ipv4-address-space.csv "https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.csv" && \
  curl -s -S -L -o $ARKIMEDIR/etc/oui.txt "https://raw.githubusercontent.com/wireshark/wireshark/master/manuf"

RUN groupadd --gid $DEFAULT_GID $PGROUP && \
    useradd -M --uid $DEFAULT_UID --gid $DEFAULT_GID --home $ARKIMEDIR $PUSER && \
      usermod -a -G tty $PUSER && \
    chmod 755 /opt/*.sh && \
    ln -sfr /opt/pcap_processor.py /opt/pcap_arkime_processor.py && \
    cp -f /opt/arkime_update_geo.sh $ARKIMEDIR/bin/arkime_update_geo.sh && \
    chmod u+s $ARKIMEDIR/bin/capture && \
    mkdir -p /var/run/arkime && \
    chown -R $PUSER:$PGROUP $ARKIMEDIR/etc $ARKIMEDIR/logs /var/run/arkime
#Update Path
ENV PATH="/opt:$ARKIMEDIR/bin:${PATH}"

EXPOSE 8000 8005 8081
WORKDIR $ARKIMEDIR

ENTRYPOINT ["/usr/local/bin/docker-uid-gid-setup.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n"]


# to be populated at build-time:
ARG BUILD_DATE
ARG MALCOLM_VERSION
ARG VCS_REVISION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.version=$MALCOLM_VERSION
LABEL org.opencontainers.image.revision=$VCS_REVISION
