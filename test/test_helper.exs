{:ok, _} = ExWsChannels.Supervisor.start_link([])
ExWs.Supervisor.start_link([
	port: 4546,
	handler: ExWsChannels.Tests.Handler
])
ExUnit.start()
