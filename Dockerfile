# ---- Base ----
FROM node:20-alpine AS base
WORKDIR /app

# ---- Dependencies ----
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

# ---- Builder ----
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ---- Runner ----
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3005
ENV HOSTNAME=0.0.0.0

# Install nginx
RUN apk add --no-cache nginx

# Copy standalone Next.js build
COPY --from=builder /app/.next/standalone ./

# Copy static assets explicitly (fixes 404 on /_next/static/)
COPY --from=builder /app/.next/static ./.next/static

# Copy public folder
COPY --from=builder /app/public ./public

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy start script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose ports
EXPOSE 80 3005

# Start
CMD ["/app/start.sh"]



# # ---- Base ----
# FROM node:20-alpine AS base
# WORKDIR /app

# # ---- Dependencies ----
# FROM base AS deps
# COPY package.json package-lock.json ./
# RUN npm ci

# # ---- Builder ----
# FROM base AS builder
# COPY --from=deps /app/node_modules ./node_modules
# COPY . .
# RUN npm run build

# # ---- Runner ----
# FROM node:20-alpine AS runner

# WORKDIR /app

# ENV NODE_ENV=production
# ENV PORT=3005
# ENV HOSTNAME=0.0.0.0

# # Install nginx
# RUN apk add --no-cache nginx

# # Copy app files
# COPY --from=builder /app ./

# # Copy nginx config
# COPY nginx.conf /etc/nginx/nginx.conf

# # Copy start script
# COPY start.sh /app/start.sh
# RUN chmod +x /app/start.sh

# # Expose ports
# EXPOSE 80 3005

# # Start script
# CMD ["/app/start.sh"]