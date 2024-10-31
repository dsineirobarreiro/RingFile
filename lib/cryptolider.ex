defmodule Cryptolider do
  @moduledoc """
  Módulo que implementa el elemento líder de esta arquitectura lider-trabajador donde permitiremos cifrar y guardar archivos.
   Posee un pool de procesos trabajadores que van recibiendo las peticiones, así como la capacidad de
   crear y destruir dichos trabajadores para manejar correctamente el número de peticiones que recibe.
   Implementa GenServer.
  """

  @petitions_check 60000
  @starting_processes 5

  use GenServer
  require Logger
  @doc """
    Inicia el componente líder.
  """
  @spec start_link(term()) :: {:ok, pid()}
  def start_link(peer) do
    GenServer.start_link(__MODULE__, peer)
  end

@doc """
  Para el componente líder.
 """
  @spec stop() :: :ok
  def stop() do
    Logger.info("Streaming stopped.")
    GenServer.stop(__MODULE__)
  end

@doc """
    Envía el archivo a cifrar a un trabajador.
"""
  @spec cypher_file(pid(), String.t()) :: :ok
  def cypher_file(leader, file) do
    GenServer.cast(leader, {:cypher_file, file})
  end

  @doc """
    Envía el archivo a descifrar a un trabajador.
  """
  @spec decypher_file(pid(), {pid(), String.t()}) :: :ok
  def decypher_file(leader, {source, text}) do
    GenServer.cast(leader, {:decypher_file, {source, text}})
  end


#GenServer callbacks
  @impl true
  def init(peer) do
    Logger.info("Peer Leader initialized")
    Process.send_after(self(), :petitions_check, @petitions_check)
    {:ok, {[],generate_processes([], @starting_processes), 0, peer}}
  end

  @impl true
  def handle_cast({:cypher_file, file}, {using, free, last_petitions, peer}) do
      Logger.info("File no cyphered in leader")
      pid = get_free_process(free)
      Cryptoworker.cypher_file(pid,file)
      {:noreply, {[pid | using], List.delete(free, pid), last_petitions+1, peer}}
  end

  def handle_cast({:decypher_file, {source, text}}, {using, free, last_petitions, peer}) do
    Logger.info("File cyphered in leader")
    pid = get_free_process(free)
    Cryptoworker.decypher_file(pid,{source,text})
    {:noreply, {[pid | using], List.delete(free, pid), last_petitions+1, peer}}
end

  def handle_cast({:cyphered_file, worker, {title, cyphered_file}},{using, free, last_petitions, peer}) do
    Logger.info("File cyphered in leader")
    GenServer.cast(peer, {:cyphered_file,{title, cyphered_file}})
    {:noreply, {List.delete(using, worker), [worker | free], last_petitions, peer}}
  end

  def handle_cast({:decyphered_file, worker, {source, decyphered}},{using, free, last_petitions, peer}) do
    Logger.info("File decyphered in leader")
    GenServer.cast(peer, {:decyphered_file, {source, decyphered}})
    {:noreply, {List.delete(using, worker), [worker | free], last_petitions, peer}}
  end

  @impl true
  def handle_info(:petitions_check, {using, free, last_petitions, peer}) do
    Logger.info("PETITIONS CHECK")
    Process.send_after(self(), :petitions_check, @petitions_check)
    if length(free)>last_petitions do
      {:noreply, {using, stop_processes(free, (length(free)-last_petitions)),0, peer}}
    else
      {:noreply, {using, free, 0, peer}}
    end
  end

  defp stop_processes(list, 0), do: list
  defp stop_processes(list, count) do
    {pid, new_list} = List.pop_at(list,0)
    GenServer.stop(pid)
    stop_processes(new_list, count-1)
  end


  defp get_free_process(list) do
    if length(list)!=0 do
      List.first(list)
    else
      {:ok, pid} = Cryptoworker.start_link(self())
      pid
    end
  end


  defp generate_processes(list, 0), do: list
  defp generate_processes(list, count) do
    {:ok, pid} = Cryptoworker.start_link(self())
    generate_processes([pid | list], count-1)
  end
end
