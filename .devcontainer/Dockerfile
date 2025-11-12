FROM docker.io/zmkfirmware/zmk-build-arm:stable

COPY .bashrc tmp
RUN mv /tmp/.bashrc ~/.bashrc

RUN apt-get update && apt-get install -y --no-install-recommends \
    yq \
    && rm -rf /var/lib/apt/lists/*