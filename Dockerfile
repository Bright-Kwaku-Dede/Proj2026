# ---------- Base ----------
FROM node:18-alpine AS base
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package*.json ./

# ---------- Dependencies ----------
FROM base AS dependencies
ENV NODE_ENV=production
# Force install ignoring peer dependency conflicts
RUN npm ci --omit=dev --legacy-peer-deps

# ---------- Production ----------
FROM node:18-alpine AS production
WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production
ENV PORT=3000

USER nodejs

EXPOSE 3000

# Health check to verify app is running
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "index.js"]
