# Stage 1: Dependencies
FROM oven/bun:1.0.2-alpine AS deps
WORKDIR /app

# Install node for compatibility
RUN apk add --no-cache nodejs

# Copy package files
COPY package.json bun.lockb ./
COPY packages/*/package.json ./packages/
COPY apps/*/package.json ./apps/

# Install dependencies
RUN bun install --frozen-lockfile

# Stage 2: Builder
FROM oven/bun:1.0.2-alpine AS builder
WORKDIR /app

# Install node and other dependencies
RUN apk add --no-cache nodejs openssl

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages ./packages
COPY --from=deps /app/apps ./apps

# Copy source code
COPY . .

# Set environment variables for build
ENV SKIP_ENV_VALIDATION=true
ENV NODE_ENV=production

# Generate Prisma client
RUN cd packages/prisma && bun run prisma generate

# Build the application
RUN bun run build

# Stage 3: Runner
FROM oven/bun:1.0.2-alpine AS runner
WORKDIR /app

# Install node and other runtime dependencies
RUN apk add --no-cache nodejs openssl

ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy necessary files from builder
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/package.json ./
COPY --from=builder /app/bun.lockb ./

# Copy built Next.js application
COPY --from=builder --chown=nextjs:nodejs /app/apps/next/.next ./apps/next/.next
COPY --from=builder --chown=nextjs:nodejs /app/apps/next/public ./apps/next/public
COPY --from=builder --chown=nextjs:nodejs /app/apps/next/package.json ./apps/next/

# Copy workspace packages needed at runtime
COPY --from=builder --chown=nextjs:nodejs /app/packages ./packages
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules

# Copy turbo and workspace configuration
COPY --from=builder /app/turbo.json ./
COPY --from=builder /app/tsconfig.base.json ./

USER nextjs

EXPOSE 3000

CMD ["bun", "start"]
