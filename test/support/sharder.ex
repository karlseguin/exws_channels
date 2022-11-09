defmodule ExWsChannels.Tests.Sharder do
	def shards(<<"large", _::binary>>), do: 7
	def shards(<<"medium", _::binary>>), do: 4
	def shards(_), do: 1
end
