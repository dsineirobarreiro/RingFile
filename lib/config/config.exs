import Config

config :cryptopeer, CryptoVault,
  ciphers: []

import_config "#{config_env()}.exs"
