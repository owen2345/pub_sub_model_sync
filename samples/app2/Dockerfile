FROM ruby:2.7.1 AS builder

# Allow apt to work with https-based sources
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends apt-transport-https

RUN mkdir /app
WORKDIR /app

# backend
COPY Gemfile.lock Gemfile /app/
RUN gem install bundler && bundle install

COPY . /app
