# syntax=docker/dockerfile:1
# Base image with all dependencies pre-installed
# This image already contains:
# - Ruby 3.3.5, Node.js 22.x
# - All gems from Gemfile.lock
# - All npm packages from package-lock.json
FROM ghcr.io/clacky-ai/rails-base-template:latest

# Base image uses /app as WORKDIR
WORKDIR /app

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    PATH="${PATH}:/home/ruby/.local/bin:/node_modules/.bin:/usr/local/bundle/bin" \
    USER="ruby" \
    PORT="3000"

# Copy application code (overwrites the code from base image)
COPY --chown=ruby:ruby . .

# Precompile assets (gems and npm packages already installed in base image)
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Clean up
RUN rm -rf tmp/cache/* log/* node_modules/.cache

ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE ${PORT}
CMD ["./bin/rails", "server"]