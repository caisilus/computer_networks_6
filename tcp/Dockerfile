FROM ruby

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

EXPOSE 28563

COPY server.rb database.rb ./

CMD ["ruby", "server.rb"]