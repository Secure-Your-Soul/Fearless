#FROM archlinux:latest
#RUN pacman -Sy --noconfirm make
#FROM fedora:minimal-44
#RUN dnf install -y make
FROM debian:trixie-slim
#FROM ubuntu:24.04-minimal
RUN apt-get update && apt-get install -y make
WORKDIR /build
COPY . .