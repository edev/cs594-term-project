FROM ruby:2.6.5

ENV APP_HOME /app
ENV DAEMON true

WORKDIR $APP_HOME

RUN gem install bundler
COPY Gemfile Gemfile.lock ./
RUN bundle install

EXPOSE 2019

copy lib/* lib/
COPY server ./

CMD ["bundle", "exec", "server"]
