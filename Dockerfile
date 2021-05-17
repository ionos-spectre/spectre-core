FROM ruby:3.0.0

COPY . /spectre/

RUN cd spectre; rake install

WORKDIR /specs
ENTRYPOINT [ "spectre" ]
