FROM ruby:3.0.2-alpine3.14

COPY . /spectre/

WORKDIR /spectre

RUN bundle update --bundler
RUN bundle install
RUN bundle exec rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
