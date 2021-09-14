FROM ruby:3-alpine

COPY . /spectre/

WORKDIR /spectre

RUN apk --update-cache add ruby-bundler
RUN bundle install
RUN bundle exec rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
