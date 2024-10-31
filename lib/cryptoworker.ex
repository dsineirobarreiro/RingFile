defmodule Cryptoworker do
  @moduledoc """
    Módulo que implementa un trabajador de esta arquitectura que se caracteriza
    por permitir el cifrado y descifrado de archivos.
    Implementa GenServer.
  """

  use GenServer
  require Logger
  @doc """
  Inicia el componente trabajador
  """
  @spec start_link(term()) :: {:ok, pid()}
  def start_link(from) do
    GenServer.start_link(__MODULE__, from)
  end


  @doc """
    Cifra el archivo
  """
  @spec cypher_file(pid(), String.t()) :: :ok
  def cypher_file(pid, file) do
    GenServer.cast(pid, {:cypher, file})
  end

  @doc """
    Descifra el archivo
  """
  @spec decypher_file(pid(), {pid(), String.t()}) :: :ok
  def decypher_file(pid, {source, text}) do
    GenServer.cast(pid, {:decypher, {source, text}})
  end

  #GenServer callbacks
  @impl true
  def init(leader) do
    Logger.info("Worker #{inspect self()} prepared.")
    {:ok, leader}
  end

  @impl true
  def handle_cast({:cypher, file}, leader) do
    Logger.info("Cifrando archivo #{file}...")
    #Sleep de 2 segundos para poder demostrar que se trabaja simultáneamente.
    Process.sleep(2*1000)
    text = File.read!(file)
    Logger.info("Texto del archivo :\n#{text}")
    cyphered = CryptoVault.encrypt!(text)
    Logger.info("Texto del archivo cifrado: #{inspect(cyphered)}")
    GenServer.cast(leader, {:cyphered_file, self(), {file, cyphered}})
    {:noreply, leader}
  end

  @impl true
  def handle_cast({:decypher, {source, text}}, leader) do
    Logger.info("Descifrando archivo #{inspect(text)}...")
    decyphered = CryptoVault.decrypt!(text)
    GenServer.cast(leader, {:decyphered_file, self(), {source, decyphered}})
    {:noreply, leader}
  end
end
