# ─────────────────────────────────────────────────────────────
# Stage 1 — deps
# Only installs production dependencies.
# Kept separate so a source-code change doesn't bust this layer.
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy manifests first so Docker can cache this layer independently
COPY package*.json ./

# `npm ci` is stricter than `npm install`:
#   - Fails if package-lock.json is out of sync (supply-chain safety)
#   - Never modifies package-lock.json
#   - Always does a clean install
RUN npm ci --omit=dev \
    --fetch-retry-mintimeout=20000 \
    --fetch-retry-maxtimeout=120000 \
    --fetch-retries=5


# ─────────────────────────────────────────────────────────────
# Stage 2 — builder
# Compiles the Next.js app. Build tooling stays here and never
# reaches the final image.
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy production deps from stage 1 (no devDependencies needed for build)
COPY --from=deps /app/node_modules ./node_modules

# Copy source last so code changes don't invalidate the node_modules layer
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# Assemble the standalone output in one step
RUN cp -r .next/static  .next/standalone/.next/static && \
    cp -r public        .next/standalone/public


# ─────────────────────────────────────────────────────────────
# Stage 3 — runner (production image)
# Nothing from the builder except the compiled output.
# No source code. No build tools. Minimal attack surface.
# ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

# Install wget for the health check probe (curl is not in alpine by default)
# Use --no-cache to avoid leaving the apk index layer in the image
RUN apk add --no-cache wget

WORKDIR /app

# Create a non-root user before copying any files so ownership is set correctly
# from the start — avoids a separate chown layer at the end
RUN addgroup -S appgroup && \
    adduser  -S appuser -G appgroup

# Copy only the standalone output — source, node_modules, and build
# tooling are all left behind in earlier stages
COPY --from=builder --chown=appuser:appgroup /app/.next/standalone ./
COPY --from=builder --chown=appuser:appgroup /app/.next/static     ./.next/static
COPY --from=builder --chown=appuser:appgroup /app/public           ./public
COPY --chown=appuser:appgroup start.sh ./

# Fix Windows line endings and make executable in one layer
RUN sed -i 's/\r//' start.sh && chmod +x start.sh

# ── Security: run as non-root ──────────────────────────────
USER appuser

# ── Security: declare which port the app listens on ───────
# EXPOSE is documentation and enables automatic port mapping with -P.
# It does NOT open a firewall hole by itself.
EXPOSE 3005

ENV PORT=3005
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# ── Health check ──────────────────────────────────────────
# --interval   how often Docker checks              (default: 30s)
# --timeout    max time allowed per check           (default: 30s)
# --start-period grace period after container start (default: 0s)
# --retries    failures before marked unhealthy     (default: 3)
#
# A /api/health endpoint is ideal; fall back to the root page if you
# don't have one yet.
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget -qO- http://localhost:3005/api/health || exit 1

CMD ["./start.sh"]


# FROM node:20-alpine

# WORKDIR /app

# RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# COPY package*.json ./

# RUN npm install --fetch-retry-mintimeout 20000 --fetch-retry-maxtimeout 120000 --fetch-retries 5

# COPY . .

# ENV NEXT_TELEMETRY_DISABLED=1
# ENV PORT=3005

# RUN npm run build

# RUN cp -r .next/static .next/standalone/.next/static && \
#     cp -r public .next/standalone/public

# COPY start.sh .
# RUN sed -i 's/\r//' start.sh && chmod +x start.sh   # ← fixes Windows line endings

# RUN chown -R appuser:appgroup /app

# USER appuser

# EXPOSE 3005

# CMD ["./start.sh"]