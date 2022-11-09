import Config

config :exws_channels,
	sharder: ExWsChannels.Tests.Sharder

if System.get_env("AB") == "1" do
	import_config "ab.exs"
end
