FROM ruby:3.3-slim

ENV LANG=C.UTF-8 BUNDLE_JOBS=4

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential git curl libpq-dev libyaml-dev \
    nodejs npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf ~/.bundle

COPY . .

RUN yarn install \
  && yarn build && yarn build:css \
  && SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

EXPOSE 3000

CMD ["bash", "-c", "bin/rails db:prepare && bin/rails server -b 0.0.0.0 -p 3000"]
