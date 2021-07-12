FROM alpine

RUN apk add --update ruby ruby-etc

COPY . /spectre/

WORKDIR /spectre

RUN gem install bundler
RUN bundle update --bundler
RUN bundle install
RUN bundle exec rake install

WORKDIR /specs

ENTRYPOINT [ "spectre" ]
