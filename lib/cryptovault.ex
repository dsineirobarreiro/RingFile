defmodule CryptoVault do
  @moduledoc """
  Módulo de encriptado. Posee la configuración necesaria para poder cifrar y descifrar archivos.
  """
  use Cloak.Vault, otp_app: :cryptopeer

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: Base.decode64!("m4ztS2gB5CGLWsPeS4AcoDoUfhet8NfDkib4azXB2mU="),
          # In AES.GCM, it is important to specify 12-byte IV length for
          # interoperability with other encryption software. See this GitHub
          # issue for more details:
          # https://github.com/danielberkompas/cloak/issues/93
          #
          # In Cloak 2.0, this will be the default iv length for AES.GCM.
          iv_length: 12
        }
      )

    {:ok, config}
  end
end
