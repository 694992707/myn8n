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

# Install all dependencies
RUN pnpm install --frozen-lockfile --reporter=append-only

# Build packages (exposes real build errors in logs)
RUN pnpm build --summarize --reporter=append-only

# Create production deploy directory
RUN NODE_ENV=production DOCKER_BUILD=true pnpm --filter=n8n --prod --legacy deploy --no-optional ./compiled

# Production stage
FROM node:22-alpine

LABEL "language"="nodejs"
LABEL "framework"="n8n"

# Install runtime dependencies
RUN apk add --no-cache \
    tini \
    curl

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
    CMD-SHELL curl -f http://localhost:${N8N_PORT}/healthz || exit 1

# Use tini as init system
ENTRYPOINT ["tini", "--"]

# Start n8n
CMD ["node", "packages/cli/bin/n8n"]
