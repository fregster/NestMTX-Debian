ARG IMAGE_PREFIX=
ARG NODE_VERSION=22
ARG NODE_IMAGE=node:${NODE_VERSION}-bookworm
ARG BUILDPLATFORM=amd64
FROM --platform=${BUILDPLATFORM} ${IMAGE_PREFIX}${NODE_IMAGE} AS base

##################################################
# Setup the Base Container
##################################################
ENV LC_ALL=C.UTF-8

RUN echo "Updating core OS" && \
    apt update && apt upgrade -y && apt install -y wget curl && apt clean

RUN echo "Installing cuda drivers" && \
    wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt update && \
    apt install -y nvidia-driver-cuda cuda-toolkit && \
    apt clean

RUN echo "Installing packages..." && \
    apt update && apt install -y dumb-init \
    openssl \
    ffmpeg \
    libgstreamer1.0-0 \
    libgstreamer1.0-dev \
    gstreamer1.0-tools \
    gstreamer1.0-rtsp \
    gstreamer1.0-libcamera \
    gstreamer1.0-libav \
    gstreamer1.0-vaapi \
    gstreamer1.0-python3-plugin-loader \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-plugins-rtp \
    pybuild-plugin-autopkgtest \
    python3 \
    pkg-config \
    python3-cairo-dev \
    libsdl-pango-dev \
    libjpeg-dev \
    libgif-dev \
    g++ \
    make \
    && apt clean  && \
    mkdir -p /home/node/app && \
    mkdir -p /home/node/app/tmp && \
    chown -R node:node /home/node/app && \
    mkdir -p /home/node/mediamtx && \
    chown -R node:node /home/node/mediamtx

WORKDIR /home/node/app
USER node
RUN yarn config set network-timeout 300000 -g

##################################################
# Build the GUI
##################################################
FROM base AS gui
ARG VERSION=unknown
ENV NODE_ENV=development
COPY --chown=node:node ./gui/package*.json ./
COPY --chown=node:node ./gui/npm* ./
COPY --chown=node:node ./gui/yarn* ./
RUN yarn install --frozen-lockfile --production=false --ignore-engines
COPY --chown=node:node ./gui .
RUN yarn build --verbose

##################################################
# Setup Dependencies
##################################################
FROM base AS dependencies
ENV NODE_ENV=development
COPY --chown=node:node ./package*.json ./
COPY --chown=node:node ./npm* ./
COPY --chown=node:node ./yarn* ./
USER node
RUN yarn install --frozen-lockfile

##################################################
# Setup Production Dependencies
##################################################
FROM base AS production-dependencies
ENV NODE_ENV=production
USER node
COPY --chown=node:node ./package*.json ./
COPY --chown=node:node ./npm* ./
COPY --chown=node:node ./yarn* ./
RUN yarn install --frozen-lockfile --production=true

##################################################
# Build
##################################################
FROM base AS build
ENV NODE_ENV=production
COPY --from=dependencies /home/node/app/node_modules /home/node/app/node_modules
ADD --chown=node:node . .
ENV MEDIA_MTX_PATH=/home/node/mediamtx/mediamtx
ENV MEDIA_MTX_CONFIG_PATH=/home/node/mediamtx/mediamtx.yml
RUN node ace build
RUN node ace mediamtx:install

##################################################
# Wrap for Production
##################################################
FROM base AS production
ENV NODE_ENV=production
ARG VERSION=unknown
ARG BUILDPLATFORM=local
ARG SHA=unknown
USER node
COPY --from=production-dependencies /home/node/app/node_modules /home/node/app/node_modules
COPY --from=build /home/node/app/build /home/node/app
ADD --chown=node:node /logger-transports /home/node/app/logger-transports
ADD --chown=node:node /resources /home/node/app/resources
RUN rm -rf /home/node/app/public
COPY --from=gui /home/node/app/.output/public /home/node/app/public
COPY --from=build /home/node/mediamtx /home/node/mediamtx
USER root
RUN chown -R node:node /home/node
RUN { \
    echo "VERSION=${VERSION}"; \
    echo "BUILDPLATFORM=${BUILDPLATFORM}"; \
    echo "SHA=${SHA}"; \
    } > /home/node/app/version.txt
USER node
CMD [ "dumb-init", "node", "bin/docker.js" ]
VOLUME [ "/home/node/app/tmp" ]