# Stage 1: Dependencies
FROM oven/bun:1-alpine AS deps
WORKDIR /app

# Copy workspace configuration
COPY package.json bun.lockb ./
COPY turbo.json ./
COPY tsconfig.base.json ./

# Copy all package.json files to set up workspace structure
COPY packages/auth/package.json ./packages/auth/
COPY packages/branding/package.json ./packages/branding/
COPY packages/components/package.json ./packages/components/
COPY packages/core/package.json ./packages/core/
COPY packages/cortex/package.json ./packages/cortex/
COPY packages/drizzle/package.json ./packages/drizzle/
COPY packages/emails/package.json ./packages/emails/
COPY packages/enterprise/package.json ./packages/enterprise/
COPY packages/env/package.json ./packages/env/
COPY packages/images/package.json ./packages/images/
COPY packages/inngest/package.json ./packages/inngest/
COPY packages/interfaces/package.json ./packages/interfaces/
COPY packages/lib/package.json ./packages/lib/
COPY packages/payments/package.json ./packages/payments/
COPY packages/prisma/package.json ./packages/prisma/
COPY packages/trpc/package.json ./packages/trpc/
COPY packages/types/package.json ./packages/types/

COPY apps/next/package.json ./apps/next/
COPY apps/cdn/package.json ./apps/cdn/

# Install dependencies
RUN bun install --frozen-lockfile

# Stage 2: Builder
FROM oven/bun:1-alpine AS builder
WORKDIR /app

# Install openssl for Prisma
RUN apk add --no-cache openssl

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy workspace files
COPY turbo.json ./
COPY tsconfig.base.json ./
COPY package.json bun.lockb ./

# Copy all packages
COPY packages ./packages

# Copy apps
COPY apps ./apps

# Set environment variables for build
ENV SKIP_ENV_VALIDATION=true
ENV NODE_ENV=production

# Generate Prisma client
RUN cd packages/prisma && bunx prisma generate

# Build the application (only the Next.js app)
RUN bun run build

# Stage 3: Runner
FROM oven/bun:1-alpine AS runner
WORKDIR /app

# Install openssl for Prisma
RUN apk add --no-cache openssl

ENV NODE_ENV=production
ENV PORT=3000

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy necessary files from builder
COPY --from=builder /app/apps/next/next.config.mjs ./apps/next/
COPY --from=builder /app/apps/next/instrumentation.ts ./apps/next/
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
