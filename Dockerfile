FROM node:16-bullseye-slim

WORKDIR /app

RUN apt-get update && apt-get install -y wget git

ENV SUI_VERSION="devnet-0.27.0"

RUN wget "https://github.com/MystenLabs/sui/releases/download/$SUI_VERSION/sui"
RUN chmod a+x sui

COPY package.json .
COPY yarn.lock .

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

ENV PATH="$PATH:/app"

RUN sui move build --path ./warmup

ENTRYPOINT node dist/main
