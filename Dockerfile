FROM ruby:3-alpine

COPY . /spectre/

WORKDIR /spectre

RUN bundle install
RUN bundle exec rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
