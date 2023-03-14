FROM debian:bullseye-slim as sui

WORKDIR /app

RUN apt-get update && apt-get install -y wget

ENV SUI_VERSION="devnet-0.27.0"

RUN wget "https://github.com/MystenLabs/sui/releases/download/$SUI_VERSION/sui"

RUN chmod a+x sui

#------------

FROM node:16-bullseye-slim

WORKDIR /app

COPY package.json .
COPY yarn.lock .

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

COPY --from=sui /app/sui .

ENTRYPOINT node dist/main

