FROM node:22-alpine
WORKDIR /app
COPY app/server.js .
EXPOSE 3000
CMD ["node", "server.js"]
