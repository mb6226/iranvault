FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app

RUN addgroup -S engine && adduser -S engine -G engine
USER engine

COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --omit=dev

ENV NODE_ENV=production
ENV UV_THREADPOOL_SIZE=64

EXPOSE 3000
CMD ["node", "dist/main.js"]