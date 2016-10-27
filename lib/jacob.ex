defmodule Jacob.Bot do
  use Slack

  def handle_connect(slack, state) do
    IO.puts "Connected as #{slack.me.name}"
    {:ok, state}
  end

  def handle_event(message = %{type: "message"}, slack, state) do
    result =
    [&process_dlls/1, &process_service_op/1]
    |> Enum.reduce_while(message.text, fn f, msg -> wrap_func(f, msg) end)
    # case ~r/(?<name>[-.0-9a-zA-Z]+)\.dll\b/U  |> Regex.scan(message.text) do
    #   nil -> nil
    #   [_h1|_t1] = list ->
    #     list |> Enum.map(fn [_x,x|_t] -> {x, "gacutil /l #{x}" |> String.to_char_list |> :os.cmd} end)
    #   _ -> nil
    # end
    response =
    case result do
      nil -> "I've got nothing to do sir!"
      r -> "My response for you, sir:\r\n#{result}"
      # [_h2|_t2] = list ->
      #   for {x, res} <- list, into: "", do: "#{x} --> #{res}\r\n"
    end
    # response = "Hello Sir!"
    send_message("My response sir:\r\n#{response}", message.channel, slack)
    {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, text, channel}, slack, state) do
    IO.puts "Sending your message, captain!"

    send_message(text, channel, slack)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}

  # Private functions

  defp wrap_func(func, msg) do
    case func.(msg) do
      nil -> {:cont, msg}
      x -> {:halt, x}
    end
  end

  def process_dlls(msg) do
    case ~r/(?<name>[-.0-9a-zA-Z]+)\.dll\b/U |> Regex.scan(msg) do
      nil -> nil
      [_h1|_t1] = list ->
        list |> Enum.map(fn [_x,x|_t] -> "gacutil /l #{x}" |> String.to_char_list |> :os.cmd end)
      _ -> nil
    end
  end

  def process_service_op(msg) do
    case ~r/(?P<1verb>(start|stop))\W*service\W*(?P<2service_name>[\w\$`]+)/ |> Regex.run(msg, capture: :all_names) do
      [verb,service_name|_t] ->
        apply Services, "#{verb}_service" |> String.to_atom, [service_name]
      _ -> nil
    end
  end

end
