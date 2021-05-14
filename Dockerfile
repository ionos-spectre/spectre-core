FROM ruby:3.0.0

RUN gem install mysql2

COPY . /spectre/

RUN cd spectre; rake install:full

WORKDIR /specs
ENTRYPOINT [ "spectre" ]

# docker run --rm --name spectre -v "$(pwd)\example:/specs" cneubaur/spectre list