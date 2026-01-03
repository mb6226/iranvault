FROM node:20-alpine AS builder
WORKDIR /app

COPY ../../services/order-service/package*.json ../../services/order-service/tsconfig.json ./
RUN npm ci

COPY ../../services/order-service/ .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

RUN addgroup -S os && adduser -S os -G os
USER os

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/main.js"]