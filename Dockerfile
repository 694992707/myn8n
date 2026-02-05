# Build stage
FROM node:22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++

# Install pnpm
RUN npm install -g pnpm@10.22.0

WORKDIR /app

# Skip git hook installation during install in CI/docker builds
ENV CI=true
ENV DOCKER_BUILD=true

# Copy package files first for better caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json tsconfig.json .npmrc ./
COPY .github ./.github
COPY scripts ./scripts
COPY patches ./patches
COPY packages ./packages

# Build and create production deploy directory
RUN pnpm build:deploy

# Production stage
FROM node:22-alpine

LABEL "language"="nodejs"
LABEL "framework"="n8n"

# Install runtime dependencies
RUN apk add --no-cache \
    tini

# Create n8n user
RUN addgroup -S n8n && adduser -S -G n8n n8n

WORKDIR /app/compiled

# Copy built files from builder stage
COPY --from=builder /app/compiled ./

# Environment variables
ENV NODE_ENV=production
ENV N8N_PORT=5678
ENV N8N_HOST=0.0.0.0
ENV N8N_USER_FOLDER=/home/node/.n8n

# Expose port
EXPOSE 5678

# Create data directory
RUN mkdir -p /home/node/.n8n && chown -R n8n:n8n /home/node

# Switch to n8n user
USER n8n

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:' + (process.env.N8N_PORT || 5678) + '/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]

# Use tini as init system
ENTRYPOINT ["tini", "--"]

# Start n8n
CMD ["node", "packages/cli/bin/n8n"]
