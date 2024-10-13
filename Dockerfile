FROM ruby:3.1

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# Set environment variables (you'll need to set these when deploying)
ENV WOOCOMMERCE_URL=your_woocommerce_url
ENV WOOCOMMERCE_CONSUMER_KEY=your_consumer_key
ENV WOOCOMMERCE_CONSUMER_SECRET=your_consumer_secret

EXPOSE 4567

CMD ["rackup", "--host", "0.0.0.0", "-p", "4567"]
