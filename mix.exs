defmodule ExwsChannels.MixProject do
	use Mix.Project

	def project do
		[
			app: :exws_channels,
			deps: deps(),
			version: "0.0.1",
			elixir: "~> 1.14",
			elixirc_paths: paths(Mix.env),
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			compilers: Mix.compilers,
			description: "Channel (or rooms) for exws websocket server",
			package: [
				licenses: ["MIT"],
				links: %{
					"https://github.com/karlseguin/exws" => "https://github.com/karlseguin/exws",
					"https://github.com/karlseguin/exws_channels" => "https://github.com/karlseguin/exws_channels"
				},
				maintainers: ["Karl Seguin"]
			]
		]
	end

	defp paths(:test), do: paths(:prod) ++ ["test/support"]
	defp paths(_), do: ["lib"]

	# Run "mix help deps" to learn about dependencies.
	defp deps do
		[
			{:poolboy, "~> 1.5.2"},
			{:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
			{:exws, path: "../exws", only: :test}
		]
	end
end
