FROM node:20-alpine AS builder
WORKDIR /app

COPY ../../services/risk-engine/package*.json ../../services/risk-engine/tsconfig.json ../../services/risk-engine/risk-rules.yaml ./
RUN npm ci

COPY ../../services/risk-engine/ .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

RUN addgroup -S re && adduser -S re -G re
USER re

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ../../services/risk-engine/risk-rules.yaml ./
RUN npm ci --omit=dev

ENV NODE_ENV=production