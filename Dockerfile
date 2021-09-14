FROM ruby:3-alpine

COPY . /spectre/

WORKDIR /spectre

RUN apk add sudo ruby-bundler
RUN sudo bundle update --bundler
RUN bundle install
RUN bundle exec rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
