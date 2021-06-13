FROM ruby:2.5
RUN apt-get update -qq
WORKDIR /app
COPY . /app
RUN gem update bundler
RUN bundle update
