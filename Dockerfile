# Build argument for base image registry (defaults to official GHCR)
# Can be overridden to use mirrors like ghcr.nju.edu.cn for faster pulls in China
ARG BASE_REGISTRY="ghcr.io"

FROM ${BASE_REGISTRY}/clacky-ai/rails-base-template:latest

WORKDIR /app

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    PORT="3000"

# Build arguments for mirrors (defaults to official sources)
ARG BUNDLE_MIRROR_URL="https://rubygems.org"
ARG NPM_REGISTRY="https://registry.npmjs.org"

# Check and install only missing gems (if Gemfile changed)
# bundle check returns 0 if all gems are satisfied, otherwise install
COPY --chown=ruby:ruby Gemfile Gemfile.lock ./

# Configure bundle mirror for faster gem installation during build
# This only affects the build process, not the runtime
RUN if [ "$BUNDLE_MIRROR_URL" != "https://rubygems.org" ]; then \
      echo "🚀 Using RubyGems mirror: $BUNDLE_MIRROR_URL"; \
      bundle config mirror.https://rubygems.org "$BUNDLE_MIRROR_URL"; \
    fi && \
    (bundle check || bundle install --jobs=4 --retry=3)

# Check and install only missing npm packages (if package.json changed)
COPY --chown=ruby:ruby package.json package-lock.json ./

# Configure npm registry for faster package installation during build
# This only affects the build process, not the runtime
RUN if [ "$NPM_REGISTRY" != "https://registry.npmjs.org" ]; then \
      echo "🚀 Using npm registry: $NPM_REGISTRY"; \
      npm config set registry "$NPM_REGISTRY"; \
    fi && \
    npm ci --production=false

# Copy application code
COPY --chown=ruby:ruby . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE ${PORT}
CMD ["./bin/rails", "server"]
