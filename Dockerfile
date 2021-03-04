FROM ruby:2.7-buster
RUN apt-get update -qq
WORKDIR /myapp
COPY . /myapp
RUN gem update bundler
RUN bundle install
