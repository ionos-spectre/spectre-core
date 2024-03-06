FROM ruby:3.2-alpine

COPY . /src/

WORKDIR /src

RUN apk update; apk add build-base mariadb-dev

# RUN bundle update --bundler
RUN bundle install
RUN bundle exec rake install

RUN gem install mysql2
RUN gem install spectre-http spectre-ssh spectre-mysql spectre-git spectre-ftp spectre-reporter-junit spectre-reporter-vstest spectre-reporter-html

WORKDIR /spectre
ENTRYPOINT [ "spectre" ]
