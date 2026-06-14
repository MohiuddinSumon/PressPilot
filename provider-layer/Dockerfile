FROM node:20-alpine

# node:20-alpine supports linux/arm64
WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY src/ ./src/

EXPOSE 3100
CMD ["node", "src/index.js"]
