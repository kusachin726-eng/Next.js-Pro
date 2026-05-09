FROM node:20-alpine AS base

# 1. Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

# 2. Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# 3. Production image, copy all the files and run nginx + next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Install nginx
RUN apk add --no-cache nginx

# Create necessary directories and non-root user
RUN mkdir -p /run/nginx && \
    addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    mkdir .next && \
    chown nextjs:nodejs .next

# Copy next.js build
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Copy nginx config and start script
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh ./
RUN chmod +x start.sh

# The standalone build uses the PORT environment variable
# Hostname is localhost so it only accepts connections from Nginx
ENV PORT=3005
ENV HOSTNAME="127.0.0.1"

EXPOSE 80

# We don't use USER nextjs here because Nginx needs root access to bind to port 80.
# The start.sh script will run Next.js as the nextjs user, and Nginx as root.
CMD ["./start.sh"]
