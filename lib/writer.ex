defmodule ExWsChannels.Writer do
	use GenServer

	def start_link(_) do
		GenServer.start_link(__MODULE__, nil, [])
	end

	def init(_), do: {:ok, nil}

	# channel is already the sharded name
	def handle_cast({:broadcast, channel, message}, state) do
		sockets =
			try do
				:ets.lookup_element(:exws_channels, channel, 3)
			rescue
				e in ArgumentError -> [] # what a great API ETS exposes ...
			end
		Enum.each(sockets, fn socket -> ExWs.write(socket, message) end)
		{:noreply, state}
	end
end
