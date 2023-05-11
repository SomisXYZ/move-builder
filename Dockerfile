FROM node:16-bullseye-slim

WORKDIR /app

RUN apt-get update && apt-get install -y git curl

ENV SUI_VERSION="sui-v1.0.0"

RUN curl -L "https://github.com/MystenLabs/sui/releases/download/$SUI_VERSION/sui" --output sui

RUN chmod a+x sui

COPY package.json .
COPY yarn.lock .

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

ENV PATH="$PATH:/app"

RUN /app/sui move build --path /app/template --dump-bytecode-as-base64

ENTRYPOINT node dist/main
