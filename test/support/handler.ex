defmodule ExWsChannels.Tests.Handler do
	use ExWs.Handler

	defp message(data, state) do
		case :erlang.iolist_to_binary(data) do
			<<"join:", room::binary>> ->
				ExWsChannels.join(room, pid_socket())
			<<"leave:", room::binary>> ->
				ExWsChannels.leave(room, pid_socket())
			"leave" ->
				ExWsChannels.leave(pid_socket())
		end
		write("ok")
		state
	end
end
