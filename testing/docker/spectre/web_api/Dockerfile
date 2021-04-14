FROM ruby:2.7.0

RUN gem install sinatra

COPY . /app/

EXPOSE 4567

CMD [ "rackup", "/app/config.ru", "--host", "0.0.0.0", "-p", "4567" ]
