import Config

config :still,
  dev_layout: false,
  input: Path.join(Path.dirname(__DIR__), "priv/site"),
  output: Path.join(Path.dirname(__DIR__), "."),
  pass_through_copy: [~r/.*\.png/]

import_config("#{Mix.env()}.exs")
