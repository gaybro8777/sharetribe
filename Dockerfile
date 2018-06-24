FROM ubuntu:xenial
MAINTAINER Kai Wegner <kw+dockerfile@o511.de>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y software-properties-common \
    && apt-get dist-upgrade -y
RUN add-apt-repository ppa:builds/sphinxsearch-rel22 && apt-get update 
RUN apt-get install -y software-properties-common libxml2 build-essential libmysqlclient-dev libxslt-dev libxml2-dev ruby ruby-dev nginx mysql-client sphinxsearch imagemagick curl git tzdata sendmail

RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
  done
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 7.8.0

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Install latest bundler
ENV BUNDLE_BIN=
RUN gem install bundler

# Run as non-privileged user
RUN useradd -m -s /bin/bash app \
  && mkdir /opt/app /opt/app/client /opt/app/log /opt/app/tmp && chown -R app:app /opt/app

USER app
WORKDIR /opt/app
# Create directory for Sharetribe

RUN git clone https://github.com/kai-wegner/sharetribe.git
WORKDIR /opt/app/sharetribe

ENV RAILS_ENV production

RUN bundle install --deployment --without test,development

ENV NODE_ENV production
ENV NPM_CONFIG_LOGLEVEL error
ENV NPM_CONFIG_PRODUCTION true

RUN npm install

EXPOSE 3000
CMD ["script/startup_docker.sh"]

USER root
RUN mkdir -p \
          app/assets/webpack \
          public/assets \
          public/webpack \
    && chown -R app:app \
       app/assets/javascripts \
       app/assets/webpack \
       client/app/ \
       public/assets \
       public/webpack
USER app

RUN script/prepare-assets.sh
