FROM debian:trixie-slim
RUN apt-get update && apt-get install -y make
WORKDIR /build
COPY . .