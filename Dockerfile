FROM ghcr.io/clacky-ai/rails-base-template:latest

WORKDIR /app

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    PORT="3000"

# Check and install only missing gems (if Gemfile changed)
# bundle check returns 0 if all gems are satisfied, otherwise install
COPY --chown=ruby:ruby Gemfile Gemfile.lock ./
RUN bundle check || bundle install --jobs=4 --retry=3

# Check and install only missing npm packages (if package.json changed)
COPY --chown=ruby:ruby package.json package-lock.json ./
RUN npm ci --production=false

# Copy application code
COPY --chown=ruby:ruby . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE ${PORT}
CMD ["./bin/rails", "server"]