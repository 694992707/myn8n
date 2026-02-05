ARG NODE_VERSION=22.22.0
ARG N8N_VERSION=snapshot

# Build stage
FROM node:22-alpine AS builder

RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++

RUN npm install -g pnpm@10.22.0

WORKDIR /app

ENV CI=true
ENV DOCKER_BUILD=true

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json tsconfig.json .npmrc ./
COPY .github ./.github
COPY scripts ./scripts
COPY patches ./patches
COPY packages ./packages

RUN pnpm build:deploy

# Runtime stage (official n8n base image)
FROM n8nio/base:${NODE_VERSION}

ARG N8N_VERSION
ARG N8N_RELEASE_TYPE=dev

ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}
ENV NODE_ICU_DATA=/usr/local/lib/node_modules/full-icu
ENV SHELL=/bin/sh

WORKDIR /home/node

COPY --from=builder /app/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 && \
    ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node && \
    rm -rf /root/.npm /tmp/*

EXPOSE 5678/tcp
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/n8n-io/n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version=${N8N_VERSION}
