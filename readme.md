An ETS-based (in memory) Channel (aka room) implementation for [ExWs](https://github.com/karlseguin/exws). 

# Example
Below is a sample Handler that accepts JSON messages and allows users to join, leave and send messages to any channel.

Note that the `pid_socket/0` function is a special function available within your handler. Yes, a nicer API would be great (like just being able to call `join(channel_id)`), but this way the ExWs library is fully decoupled from the ExWsChannels library. (`pid_socket/0` currently returns a tuple of the handler pid, and the socket, though this could change in the future).

```elixir
defmodule YourApp.YourWSHandler do
  use ExWs.Handler

  defp message(data, state) do
    case Jason.decode(data) do
      {:ok, data} -> process(data)
      _ -> close(3000, "invalid payload")
    end
  end
  
  defp process(%{"join" => channel}) do
    ExWsChannels.join(channel, pid_socket())
    # optionally, ack the join
    # write(Jason.encode!(%{joined: channel}))
  end
  
  defp process(%{"leave" => channel}) do
    ExWsChannels.leave(channel, pid_socket())
    # optionally, ack the leave
    # write(Jason.encode!(%{left: channel}))
  end

  defp process(%{"say" => message, "to" => channel}) do
    case ExWsChannels.member?(channel, pid_socket()) do
      true -> 
        # broadcast/2 can be called from anywhere, not just your handler
        ExWsChannels.broadcast(channel, message)
      false -> 
        # or maybe just respond with an error message
        close(3000, "cannot send to channel")  
    end
  end
end
```

## Usage
Follow the directions for installing and configuring [ExWs](https://github.com/karlseguin/exws) as usual. In addition, add the following dependency to your project:

```
{:exms_channels, "~> 0.0.1"}
```

And add `ExWsChannels.Supervisor` to your supervisor tree. This should likely be added BEFORE the `ExWs.Supervisor`:

```elixir
children = [
  # ...
  ExWsChannels.Supervisor,
  {ExWs.Supervisor, [port: 4545, handler: YourApp.YourWSHandler]}
]

## Joining a Channel
From within your handler, call `ExWsChannels.join(CHANNEL_ID, pid_socket())` to have the user join a channel named `CHANNEL_ID`. In most cases `CHANNEL_ID` will be a string or maybe an atom (it can be anything, including a mix of types).

The special `pid_socket()` function is available from within your handler.

Joining the same channel multiple times is a no-op.

When joining a channel, you can specify a 3rd optional parameter which is arbitrary data to associate with the user. This data should be kept small (like a user_id and user_name, perhaps.) It is exposed in the reduce/3 function.

## Leave one or all Channels
From within your handler, call `ExWsChannels.leave/1` to leave all channels, or `ExWsChannels.leave/2` to leave a specific channel:

```elixir
ExWsChannels.leave(pid_socket())
ExWsChannels.leave(CHANNEL_ID, pid_socket())
```

Leaving a channel that the user isn't in is safe.

## Channel Membership
Use `ExWsChannels.member?(CHANNEL_ID, pid_socket())` from within your handler to determine if the user is in the channel. Not that you can safely join the same channel multiple times without having to call `member?/2` first.

## User List
You can reduce over a list of channel members using `ExWsChannels.reduce/3`:
```elixir
ExWsChannels.reduce(channel, %{}, fn {pid, socket, meta},  ->
  #TODO
end)
```

`pid` is the handler process id. `socket` is the tcp socket (remember, it's safe to write to the socket from different processes!). `meta` is the data, if any, that was used when `join/3` was called (or `nil` if `join/2` was used).

## Write to a Channel
You can call `ExWsChannels.broadcast(CHANNEL_ID, MESSAGE)` from anywhere in your code. This does not have to be called from within your handler (but it can be).

The `broadcast/2` function can be optimized [like the `write/1` function](https://github.com/karlseguin/exws#write-optimizations).

# Advanced Configuration
A pool or writers is created on startup and used when broadcasting messages to channels. There are a few ways this can be tweaked.

The first is by controlling the size of the pool and how much it can grow to. By default, the pool size is 10, and it can grow by 5x.

When starting `ExWsChannels.Supervisor`, you can specify the `:writers` and `:max_writers` options:

```elixir
children = [
  # ...
  {ExWsChannels.Supervisor, [writers: 20, max_writers: 100]},
  {ExWs.Supervisor, [port: 4545, handler: YourApp.YourWSHandler]}
]
```

Having more writers means that separate broadcasts (either to the same channel or to different channels) aren't going to block waiting for a writer to become available. However, what about individual broadcasts to very large channels? By default, a single writer will iterate through all users and send the message.

To help deal with very large channels, channels can be "sharded". Internally, a channel with 4 shards will be split into 4 groups of users, and broadcasts to the channel will be able to use 4 writers. To enable sharding, you need to creating a sharding module:

```elixir
defmodule YourWSHandler.ChannelSharder do
  # the "general" channel is very popular, so we want more shards for it
  def shards("general"), do: 16
  def shards(_), do: 1
end
```

Next add the configuration to point to your sharder (in dev.exs and/or prod.exs):

```elixir
config :exws_channels,
  sharder: YourWSHandler.ChannelSharder
```

The built-in default sharder always returns a shard count of 1. While the implementation of your `shards/1` can be anything, do note that it can be called often, so don't make it too expensive.

Besides defining the sharding logic, there should be no other changes to your code. You still broadcast and join the channel using the same `CHANNEL_ID`.

# Misc
Since this uses ETS, it might not seem to fit within an HA/multi-server setup. It's true that, on its own, this won't be enough, but it can act as a foundation. There are a lot of ways to implement channels over a cluster of servers and for keeping them in sync, and it really depends on what you're needs are. Are you talking about 2 or 200 servers? Will you let clients connect to any server, or will you direct them to specific ones? Do you need other consistent data (like a chat history)?

Also, while I like the ETS implementation for most cases, I do believe that in some cases, GenServers with a DynamicSupervisor might work best. Specifically, if you have complex channel logic or a lot of channel state (like a history), GenServers might be a better fit.

Broadcasting to large channels (say 50K+) will probably also necessitate more consideration, such as sharded GenServers, to scale broadcasts and minimize copying of data.
