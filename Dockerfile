# syntax=docker/dockerfile:1
# Base image contains common gems and npm packages pre-installed
# If your Gemfile/package.json matches, you can reuse them directly!
FROM ghcr.io/clacky-ai/rails-base-template:latest

WORKDIR /app

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    PORT="3000"

# Check and install only missing gems (if Gemfile changed)
# bundle check returns 0 if all gems are satisfied, otherwise install
COPY --chown=ruby:ruby Gemfile Gemfile.lock ./
RUN bundle check || (bundle install --jobs=4 --retry=3 && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete)

# Check and install only missing npm packages (if package.json changed)
COPY --chown=ruby:ruby package.json package-lock.json ./
RUN npm ci --production=false

# Copy application code
COPY --chown=ruby:ruby . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Clean up
RUN rm -rf tmp/cache/* log/* node_modules/.cache

ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE ${PORT}
CMD ["./bin/rails", "server"]