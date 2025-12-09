FROM elixir:1.19

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && \
  mix local.rebar --force

COPY mix.exs mix.exs
COPY mix.lock mix.lock
RUN mix deps.get --only prod && \
  mix deps.compile

COPY . .
CMD ["mix", "run", "--no-halt"]
