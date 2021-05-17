FROM ruby:3.0.0


COPY . /spectre/

WORKDIR /spectre

RUN gem install bundler
RUN bundle update --bundler
RUN bundle install
RUN bundle exec rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
