#FROM archlinux:latest
FROM debian:trixie-slim
#FROM fedora:minimal-44
#FROM ubuntu:24.04-minimal
RUN apt-get update && apt-get install -y \
    make
WORKDIR /build
COPY . .