defmodule Cryptopeer do
  @moduledoc """
  Proceso que recibe peticiones para buscar, almacenar o enviar ficheros.
  Implementa GenServer y posee un proceso hijo que se caracteriza por ser el líder de una arquitectura líde-trabajador.
  """
  use GenServer
  require Logger


  @max_files 2

  @type t :: %Cryptopeer{next: pid(), leader: pid(), num_peers: integer(), files: list()}
  defstruct [
    :next,
    :leader,
    :num_peers,
    files: %{},
    nodes: []
  ]


  @doc """
  Inicia el proceso que busca un fichero.
  Recibe una lista [num_peers, count_peers, previous_peer].
  - num_peers : numero de peers totales.
  - count_peers : numero de peers que quedan por levantar.
  - previous_peer : pid del peer anterior en la arquitectura anillo o nil si es el primer peer.

  ## Ejemplos:

    iex> Cryptopeer.start_link([4, 4, nil])

    iex> Process.whereis(Cryptopeer) |> Process.alive?
    true

  """
  @spec start_link(term()) :: {:ok, pid()}
  def start_link([c, n, _] = args) do
    #Logger.info("GenServer Cryptopeer inizializated")
    GenServer.start_link(__MODULE__, args, name: via_tuple(n-c))
  end


  @doc """
  Envía un fichero.
  """
  @spec send_file({atom(), atom()}, String.t()) :: :ok
  def send_file({:global, peer}, file) do
    GenServer.cast({:global, peer}, {:send_file, file})
  end

  @spec send_file(String.t(), String.t()) :: :ok
  def send_file(peer, file) do
    case Registry.lookup(CryptoPeer.Registry, peer) do
      [{_, value}] -> GenServer.cast(value, {:send_file, file})
      [] -> Logger.info("No such peer in the node")
    end
  end

  @doc """
  Solicita un fichero a un peer.
  """
  @spec get_file({atom(), atom()}, String.t()) :: {:file_found, String.t()} | {:error, String.t()}
  def get_file({:global,peer},file) do
    GenServer.cast({:global, peer}, {:get_file, file, self()})
    receive do
      :found ->
        receive do
          {:ok, decyphered} -> {:file_found, decyphered}
        end
      :not_found ->
          {:error, "File not found"}
    end
  end

  @spec get_file(String.t(), String.t()) :: {:file_found, String.t()} | {:error, String.t()}
  def get_file(peer,file) do
    case Registry.lookup(CryptoPeer.Registry, peer) do
      [{_, value}] -> GenServer.cast(value, {:get_file, file, self()})
      [] -> Logger.info("No such peer in the node")
    end
    receive do
      :found ->
        receive do
          {:ok, decyphered} -> {:file_found, decyphered}
        end
      :not_found ->
          {:error, "File not found"}
    end
  end

  @doc """
  Borra la primera aparición de un fichero específico. Si se le pasase la option :all, borraría todas sus apariciones.
  """
  @spec delete_file(String.t(),String.t(), atom()) :: :ok
  def delete_file(peer, file, option \\ :first) do
    case Registry.lookup(CryptoPeer.Registry, peer) do
      [{_, value}] -> GenServer.cast(value, {:delete_file, file, option})
      [] -> Logger.info("No such peer in the node")
    end
  end

  @doc """
  Fuerza la llamada mediante el option :all de la función delete_file
  """
  @spec delete_all(String.t()) :: :ok
  def delete_all(file) do
    delete_file("peer0", file, :all)
  end

  @doc """
  Lista los archivos de cada peer del anillo.
  """
  @spec list_files(String.t()) :: :ok
  def list_files(option \\ "local") do
    case Registry.lookup(CryptoPeer.Registry, "peer0") do
      [{_, value}] -> GenServer.cast(value, {:list_files,option})
      [] -> Logger.info("No such peer in the node")
    end
  end

  #GENSERVER CALLBACKS

  #Error si no se crea ningun peer
  @spec init(term()) :: {:ok, %Cryptopeer{next: pid()}} | {:stop, reason :: any}
  @impl true
  def init([0,  _num_peers, _pid]) do
    {:stop, "Zero nodes architecture not supported"}
  end

  #Funcion que llamara el primer peer
  def init([count_peers, num_peers, nil]) do
    Logger.info("Cryptopeer peer0 initialized #{inspect(self())}")
    Registry.register(CryptoPeer.Registry, "peer0", self())
    :global.register_name(Node.self(), self())
    #Process.register(self(), __MODULE__)
    next_pid =
      case count_peers do
        1 -> nil
        _other ->
          {:ok, next_pid} = Cryptopeer.start_link([count_peers-1, num_peers, self()])
          next_pid
      end
    {:ok,leader} = Cryptolider.start_link(self())
    {:ok, %Cryptopeer{next: next_pid, leader: leader, num_peers: num_peers, files: %{}, nodes: []}}
  end

  #Funcion que llamara el ultimo peer
  def init([1, num_peers, pid]) do
    pname = "peer" <> to_string(num_peers-1)
    Logger.info("Cryptopeer #{pname} initialized #{inspect(self())}")
    Registry.register(CryptoPeer.Registry, pname, self())
    {:ok,leader} = Cryptolider.start_link(self())
    {:ok, %Cryptopeer{next: pid, leader: leader, num_peers: num_peers, files: %{}}}
  end

  #Funcion que llamaran el resto de peers
  def init([count_peers, num_peers, pid]) do
    pname = "peer" <> to_string(num_peers-count_peers)
    Logger.info("Cryptopeer #{pname} initialized #{inspect(self())}")
    Registry.register(CryptoPeer.Registry, pname, self())
    {:ok, next_pid} = Cryptopeer.start_link([count_peers-1, num_peers, pid])
    {:ok,leader} = Cryptolider.start_link(self())
    {:ok, %Cryptopeer{next: next_pid, leader: leader, num_peers: num_peers, files: %{}}}
  end

  #Handle del mensaje search del cliente.
  @impl true
  def handle_cast({:get_file, file, source}, state) do
    Logger.info("Client asking for file #{inspect(file)}")
    Logger.info("(#{inspect(self())}) #{Registry.keys(CryptoPeer.Registry, self())} searching for file #{inspect(file)}")
    internal_search(file, state.files, source, state.num_peers, state.next, state.leader, :global.registered_names())
    {:noreply, state}
  end

  #Handle del mensaje search de busqueda interna.
  def handle_cast({:get_file, file, source, num_peers, rings},state) do
    Logger.info("(#{inspect(self())}) #{Registry.keys(CryptoPeer.Registry, self())} searching for file #{inspect(file)}")
    internal_search(file, state.files, source, num_peers, state.next, state.leader, rings)
    {:noreply, state}
  end

  #Handle del mensaje search de busqueda interna.
  def handle_cast({:redirect, file, source, rings},state) do
    Logger.info("(#{inspect(self())}) #{Registry.keys(CryptoPeer.Registry, self())} searching for file #{inspect(file)}")
    internal_search(file, state.files, source, state.num_peers, state.next, state.leader, rings)
    {:noreply, state}
  end

  def handle_cast({:send_file, file}, state) do
    Logger.info("File received in #{Registry.keys(CryptoPeer.Registry, self())}")
    if length(Map.keys(state.files)) == @max_files do
      Logger.info("Max files reached in #{Registry.keys(CryptoPeer.Registry, self())}\nRedirecting to next peer.")
      GenServer.cast(state.next, {:send_file, file, state.num_peers-1})
    else
      Cryptolider.cypher_file(state.leader, file)
    end
    {:noreply, state}
  end

  def handle_cast({:send_file, file, num_peers}, state) do
    Logger.info("File received in #{Registry.keys(CryptoPeer.Registry, self())}")
    if length(Map.keys(state.files)) == @max_files do
      if num_peers == 1 do
        Logger.info("Maximum of files reached in the whole ring. Unable to store the file")
      else
        Logger.info("Max files reached in #{Registry.keys(CryptoPeer.Registry, self())}\nRedirecting to next peer.")
        GenServer.cast(state.next, {:send_file, file, num_peers-1})
      end
    else
      Cryptolider.cypher_file(state.leader, file)
    end
    {:noreply, state}
  end

  def handle_cast({:store, {title,file}, num_peers}, state) do
    Logger.info("Cyphered file received in #{Registry.keys(CryptoPeer.Registry, self())}")
    if length(Map.keys(state.files)) >= @max_files do
      if num_peers == 1 do
        Logger.info("Maximum of files reached in the whole ring. Unable to store the file")
      else
        Logger.info("Max files reached in #{Registry.keys(CryptoPeer.Registry, self())}\nRedirecting to next peer.")
        GenServer.cast(state.next, {:store, {title,file}, num_peers-1})
      end
      {:noreply, state}
    else
      {:noreply, %{state | files: Map.put(state.files, title, file)}}
    end
  end

  def handle_cast({:cyphered_file, {title,file}},  state) do
    Logger.info("Cyphered file in peer")
    if length(Map.keys(state.files)) == @max_files do
      Logger.info("Max files reached in #{Registry.keys(CryptoPeer.Registry, self())}\nRedirecting cyphered file to next peer.")
      GenServer.cast(state.next, {:store, {title,file}, state.num_peers-1})
      {:noreply, state}
    else
    {:noreply, %{state | files: Map.put(state.files, title, file)}}
    end
  end

  def handle_cast({:decyphered_file, {source, decyphered}}, state) do
    Logger.info("Decyphered file in peer")
    send(source, {:ok, decyphered})
    {:noreply, state}
  end

  def handle_cast({:list_files, option}, state) do
    case option do
      "local" -> Logger.info("Listing files of Ring #{Node.self()}:\n")
                 internal_list(state.files, state.num_peers, state.next, option)
    end
    {:noreply, state}
  end

  def handle_cast({:list_files, option, num_peers}, state) do
    case option do
      "local" -> internal_list(state.files, num_peers, state.next, option)
    end
    {:noreply, state}
  end


  def handle_cast({:delete_file, file, option}, state) do
      case option do
        :first ->
          case Map.fetch(state.files, file) do
            {:ok, _} -> Logger.info("Deleting file #{file} in #{Registry.keys(CryptoPeer.Registry,self())}")
                           {:noreply, %{state| files: Map.delete(state.files, file)}}
            :error -> Logger.info("File #{file} not found in #{Registry.keys(CryptoPeer.Registry,self())}. Redirecting to next peer.")
                      GenServer.cast(state.next, {:delete_file, file, option, state.num_peers-1})
                      {:noreply, state}
          end
        :all ->
          GenServer.cast(state.next, {:delete_file, file, option, state.num_peers-1})
          {:noreply, %{state| files: Map.delete(state.files, file)}}
      end
  end

  def handle_cast({:delete_file, file, option, num_peers}, state) do
    case option do
      :first ->
        case Map.fetch(state.files, file) do
          {:ok, _} -> Logger.info("Deleting file #{file} in #{Registry.keys(CryptoPeer.Registry,self())}")
                         {:noreply, %{state| files: Map.delete(state.files, file)}}
          :error ->
            case num_peers do
              1 -> Logger.info("File #{file} not found in ring #{inspect(Node.self())}. Unable to delete.")
              _ -> Logger.info("File #{file} not found in #{Registry.keys(CryptoPeer.Registry,self())}. Redirecting to next peer.")
                    GenServer.cast(state.next, {:delete_file, file, option, num_peers-1})
            end
            {:noreply, state}
        end
      :all ->
        if num_peers != 1, do:  GenServer.cast(state.next, {:delete_file, file, option, state.num_peers-1})
        {:noreply, %{state| files: Map.delete(state.files, file)}}
    end
end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp internal_list(files, num_peers, next_peer, option) do
    case num_peers do
      1 -> Logger.info("\n\tPeer #{Registry.keys(CryptoPeer.Registry,self())}: #{inspect(Map.keys(files))}")
      _ -> Logger.info("\n\tPeer #{Registry.keys(CryptoPeer.Registry,self())}: #{inspect(Map.keys(files))}")
           GenServer.cast(next_peer, {:list_files, option, num_peers-1})
    end
  end

  #Funcion que tiene la logica de busqueda.
  defp internal_search(file, files, source, num_peers, next_peer, leader, rings) do
    case Map.fetch(files, file) do
      {:ok, text} ->
        Cryptolider.decypher_file(leader, {source, text})
        send(source, :found)
      :error ->
        case num_peers do
          1 ->
            Logger.info("(#{inspect(self())})File #{inspect(file)} not found in Ring #{inspect(Node.self())}")
            Logger.info(inspect(rings))
            new_rings = List.delete(rings, Node.self())
            Logger.info(inspect(new_rings))
            case new_rings do
              [] -> send(source, :not_found)
              [h | _] -> Logger.info("Redirecting petition to get #{file} to Ring #{inspect(h)}}")
                        GenServer.cast({:global,h}, {:redirect, file, source, new_rings})
            end
          _other ->
            GenServer.cast(next_peer, {:get_file, file, source, num_peers-1, rings})
        end
    end
  end

  defp via_tuple(count) do
    {:via, :gproc, {:n, :l, {:peer, "peer" <> to_string(count)}}}
  end

end
