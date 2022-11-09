defmodule ExWsExWsChannels.Tests do
	use ExUnit.Case
	alias ExWsChannels.Tests.WS

	setup do
		:ets.delete_all_objects(:exws_channels)
		:ets.delete_all_objects(:exws_channels_users)
		:ok
	end

	for channel <- ["small", "medium", "large"] do
		channel_a = "#{channel}_a"
		channel_b = "#{channel}_b"
		channel_c = "#{channel}_c"

		describe "#{channel}" do
			test "user joins & leaves channel" do
				user = user_data(pid: 1)
				channel = unquote(channel)

				assert ExWsChannels.member?(channel, user) == false
				ExWsChannels.join(channel, user)
				assert ExWsChannels.member?(channel, user) == true
				assert_users(channel, [user])
				assert_metas(channel, %{user => nil})
				assert_channels(user, [channel])

				# additions joins to the same channels are no-ops
				ExWsChannels.join(channel, user)
				assert_users(channel, [user])
				assert_channels(user, [channel])

				# leave
				ExWsChannels.leave(channel, user)
				assert_users(channel, [])
				assert_channels(user, [])
				assert ExWsChannels.member?(channel, user) == false

				# with meta
				ExWsChannels.join(channel, user, {1, 2})
				assert_users(channel, [user])
				assert_users(channel, [user])
				assert_metas(channel, %{user => {1, 2}})
				assert_channels(user, [channel])
			end

			test "user joins multiple channels" do
				user = user_data(pid: 1)
				channel_a = unquote(channel_a)
				channel_b = unquote(channel_b)
				channel_c = unquote(channel_c)

				ExWsChannels.join(channel_a, user)
				ExWsChannels.join(channel_b, user)
				ExWsChannels.join(channel_c, user)
				assert_users(channel_a, [user])
				assert_users(channel_b, [user])
				assert_users(channel_c, [user])
				assert_channels(user, [channel_a, channel_b, channel_c])

				ExWsChannels.leave(channel_b, user)
				assert_users(channel_a, [user])
				assert_users(channel_b, [])
				assert_users(channel_c, [user])
				assert_channels(user, [channel_a, channel_c])
			end

			test "multiple users in channel" do
				user1 = user_data(pid: 1)
				user2 = user_data(pid: 2)
				user3 = user_data(pid: 3)
				channel = unquote(channel)

				ExWsChannels.join(channel, user1)
				ExWsChannels.join(channel, user2)
				ExWsChannels.join(channel, user3)
				assert_channels(user1, [channel])
				assert_channels(user2, [channel])
				assert_channels(user3, [channel])
				assert_users(channel, [user1, user2, user3])

				ExWsChannels.leave(channel, user2)
				assert_users(channel, [user1, user3])

				# can leave again, no-op
				ExWsChannels.leave(channel, user2)
				assert_users(channel, [user1, user3])

				# more leave
				ExWsChannels.leave(channel, user1)
				assert_users(channel, [user3])

				# more leave
				ExWsChannels.leave(channel, user3)
				assert_users(channel, [])
			end

			test "many users in channel" do
				channel = unquote(channel)

				users = Enum.reduce(1..1_000, [], fn i, users ->
					user = user_data(pid: i)
					ExWsChannels.join(channel, user)
					assert ExWsChannels.member?(channel, user) == true
					[user | users]
				end)
				assert_users(channel, users)

				Enum.reduce(users, users, fn user, users ->
					ExWsChannels.leave(channel, user)
					assert ExWsChannels.member?(channel, user) == false
					users = tl(users)
					assert_users(channel, users)
					users
				end)
			end

			test "broadcast" do
				channel = unquote(channel)
				sockets = Enum.reduce(1..100, [], fn _, sockets ->
					s = WS.connect()
					sockets = [s | sockets]

					WS.write(s, "join:#{channel}")
					assert WS.read(s) == "ok"  # need to wait until we're sure it's done joining
					ExWsChannels.broadcast(channel, "over 9000!")

					Enum.each(sockets, fn s ->
						assert WS.read(s) == "over 9000!"
					end)

					sockets
				end)

				Enum.reduce(sockets, sockets, fn socket, sockets ->
					WS.close(socket)
					ExWsChannels.broadcast(channel, ExWs.txt("ghanima"))

					sockets = tl(sockets)

					Enum.each(sockets, fn s ->
						assert WS.read(s) == "ghanima"
					end)

					sockets
				end)
			end
		end
	end

	# simulate an ExWs data object (the data we expect ExWs to pass us)
	defp user_data(opts) do
		{
			opts[:pid] || :rand.uniform(1000),
			opts[:socket] || :rand.uniform(1000),
		}
	end

	defp assert_users(channel, users) do
		actuals = ExWsChannels.reduce(channel, [], fn {pid, _, _}, actuals ->
			[pid | actuals]
		end)

		expected = Enum.reduce(users, [], fn user, expected ->
			[elem(user, 0) | expected] # grab the pid
		end)

		assert Enum.sort(actuals) == Enum.sort(expected)
	end

	defp assert_metas(channel, metas) do
		actuals = ExWsChannels.reduce(channel, %{}, fn {pid, _, meta}, metas ->
			Map.put(metas, pid, meta)
		end)

		expected = Enum.reduce(metas,  %{}, fn {user, meta}, metas ->
			Map.put(metas, elem(user, 0), meta)
		end)

		assert actuals == expected
	end

	defp assert_channels(user, expected) do
		actuals = ExWsChannels.channels(user)
		assert Enum.sort(actuals) == Enum.sort(expected)
	end
end
