FROM node:20-alpine AS builder
WORKDIR /app

COPY ../../services/market-data-service/package*.json ../../services/market-data-service/tsconfig.json ./
RUN npm ci

COPY ../../services/market-data-service/ .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

RUN addgroup -S md && adduser -S md -G md
USER md

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/main.js"]