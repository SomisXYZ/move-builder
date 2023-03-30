FROM node:16-bullseye-slim

WORKDIR /app

RUN apt-get update && apt-get install -y git curl

ENV SUI_VERSION="devnet-0.29.0"

RUN curl -L "https://github.com/MystenLabs/sui/releases/download/$SUI_VERSION/sui" --output sui

RUN chmod a+x sui

COPY package.json .
COPY yarn.lock .

RUN yarn install --frozen-lockfile

COPY . .

RUN yarn build

ENV PATH="$PATH:/app"

RUN cp -r /app/template /app/warmup;\
  mv /app/warmup/sources/module.move.template /app/warmup/sources/suiseals.move; \
  sed -i 's/{{ name_upper_no_space }}/SUISEALS/g' /app/warmup/sources/suiseals.move; \
  sed -i 's/{{ name_no_space }}/SuiSeals/g' /app/warmup/sources/suiseals.move; \
  sed -i 's/{{ name_lower_no_space }}/suiseals/g' /app/warmup/sources/suiseals.move; \
  sed -i 's/{{ royalty }}/100/g' /app/warmup/sources/suiseals.move; \
  sed -i 's/{{ name_no_space }}/SuiSeals/g' /app/warmup/Move.toml; \
  sed -i 's/{{ name_lower_no_space }}/suiseals/g' /app/warmup/Move.toml;

RUN /app/sui move build --path /app/warmup --dump-bytecode-as-base64

ENTRYPOINT node dist/main
