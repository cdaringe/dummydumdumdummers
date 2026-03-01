# docker buildx build --platform=linux/amd64 -t thingfactory-web -f web/Dockerfile web

# Stage 1: Build Next.js on native arch (no QEMU needed, fast).
# --ignore-scripts skips native addon compilation since next build
# won't load better-sqlite3 (lazy init via proxy in lib/db.ts).
FROM --platform=$BUILDPLATFORM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY . .
RUN npm run build

# Stage 2: Compile native modules for the target platform
FROM node:22-alpine AS native-deps

WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package.json package-lock.json ./
RUN npm ci

# Stage 3: Runtime
FROM node:22-alpine

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/db/migrations ./db/migrations
# Overlay correctly compiled native module for target platform
COPY --from=native-deps /app/node_modules/better-sqlite3 ./node_modules/better-sqlite3

RUN mkdir -p /app/data

EXPOSE 3000

CMD ["node", "server.js"]
