defmodule ExWsChannels.Supervisor do
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, opts)
	end

	def init(opts) do
		:ets.new(:exws_channels, [:duplicate_bag, :public, :named_table, write_concurrency: true, read_concurrency: true])
		:ets.new(:exws_channels_users, [:duplicate_bag, :public, :named_table, write_concurrency: true, read_concurrency: true])

		writers = Keyword.get(opts, :writers, 10)
		max_writers = Keyword.get(opts, :max_writers, writers * 5)
		children = [
			:poolboy.child_spec(:exws_channels_writer, [size: writers, max_overflow: max_writers, name: {:local, :exws_channels_writer}, worker_module: ExWsChannels.Writer], []),
		]

		Supervisor.init(children, strategy: :one_for_one)
	end
end
