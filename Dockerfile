FROM node:20-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY package*.json ./

RUN npm install --fetch-retry-mintimeout 20000 --fetch-retry-maxtimeout 120000 --fetch-retries 5

COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3005

RUN npm run build

RUN cp -r .next/static .next/standalone/.next/static && \
    cp -r public .next/standalone/public

COPY start.sh .
RUN sed -i 's/\r//' start.sh && chmod +x start.sh   # ← fixes Windows line endings

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3005

CMD ["./start.sh"]