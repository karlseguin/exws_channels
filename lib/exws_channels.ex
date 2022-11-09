defmodule ExWsChannels do
	@sharder Application.compile_env(:exws_channels, :sharder, ExWsChannels)

	def join(channel, {pid, socket}, meta \\ nil) do
		channel = sharded(channel, pid)
		user_data = {pid, channel}
		if match?([], :ets.match(:exws_channels_users, user_data)) do
			:ets.insert(:exws_channels_users, user_data)
			:ets.insert(:exws_channels, {channel, pid, socket, meta})
		end
	end

	def leave(channel, {pid, _socket}) do
		channel = sharded(channel, pid)
		:ets.match_delete(:exws_channels_users, {pid, channel})
		:ets.match_delete(:exws_channels, {channel, pid, :_, :_})
	end

	def leave({pid, _socket}) do
		Enum.each(:ets.lookup(:exws_channels_users, pid), fn {_pid, channel} ->
			:ets.match_delete(:exws_channels, {channel, pid, :_, :_})
		end)
		:ets.delete(:exws_channels_users, pid)
	end

	def member?(channel, {pid, _socket}) do
		channel = sharded(channel, pid)
		# ets.member doesn't work like I think it should for duplicate_bags??
		:ets.match(:exws_channels_users, {pid, channel}) == [[]]
	end

	def broadcast(channel, message, opts \\ []) do
		shards = @sharder.shards(channel) - 1
		Enum.each(0..shards, fn shard ->
			:poolboy.transaction(:exws_channels_writer, fn pid ->
				GenServer.cast(pid, {:broadcast, {channel, shard}, message})
			end, opts[:timeout] || 30_000)
		end)
	end

	def channels({pid, _socket}) do
		channels = :ets.lookup(:exws_channels_users, pid)
		Enum.reduce(channels, [], fn
			{_pid, {channel, _shard}}, acc -> [channel | acc]
			{_pid, channel}, acc -> [channel | acc]
		end)
	end

	def reduce(channel, acc, fun) do
		shards = @sharder.shards(channel) - 1
		Enum.reduce(0..shards, acc, fn shard, acc ->
			users = :ets.lookup(:exws_channels, {channel, shard})
			Enum.reduce(users, acc, fn {_channel, pid, socket, meta}, acc ->
				fun.({pid, socket, meta}, acc)
			end)
		end)
	end

	# Channels can be sharded. Sharding allows concurrent writers to
	# broadcast to users. When sharded, the internal channel name (
	# which is the key in our ETS, becomes {channel, H(pid) % SHARD_COUNT}).
	defp sharded(channel, pid) do
		case @sharder.shards(channel) do
			1 -> {channel, 0} # can avoid the phash2 here
			shards -> {channel, rem(:erlang.phash2(pid), shards)}
		end
	end

	# default implementation
	@doc false
	def shards(_), do: 1
end
