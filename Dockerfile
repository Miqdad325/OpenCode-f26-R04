FROM oven/bun:1.3.14

RUN apt-get update \
  && apt-get install -y --no-install-recommends git \
  && apt-get install -y python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces/OpenCode-f26-R04


COPY . .

RUN bun install

EXPOSE 4096

CMD ["bun", "run", "packages/opencode/src/index.ts", "web", "--hostname", "0.0.0.0", "--port", "4096"]
