defmodule Cryptopeer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    num_peers = 4
    children = [
      # Starts a worker by calling: Cryptopeer.Worker.start_link(arg)
      # {Cryptopeer.Worker, arg}
      {Registry, keys: :unique, name: CryptoPeer.Registry},
      Supervisor.child_spec({Cryptopeer, [num_peers, num_peers, nil]}, id: :Crypto1),
      CryptoVault
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cryptopeer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
