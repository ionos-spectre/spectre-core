FROM ruby:3.1-alpine

COPY . /src/

WORKDIR /src

RUN apk update; apk add build-base mariadb-dev

# RUN bundle update --bundler
RUN bundle install
RUN bundle exec rake install

RUN gem install mysql2
RUN gem install spectre-ssh spectre-mysql spectre-git spectre-ftp

WORKDIR /spectre
ENTRYPOINT [ "spectre" ]
