#FROM archlinux:latest
FROM debian:bookworm-slim
#FROM fedora:minimal-44
#FROM ubuntu:24.04-minimal
WORKDIR /build
COPY . .
RUN make