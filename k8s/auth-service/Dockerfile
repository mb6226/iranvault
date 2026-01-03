# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application (if needed)
RUN npm run build || true

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 authuser

# Copy built application
COPY --from=builder /app ./

# Change ownership
RUN chown -R authuser:nodejs /app

# Switch to non-root user
USER authuser

EXPOSE 3000

ENV PORT=3000

# Start the application
CMD ["npm", "start"]