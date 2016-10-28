defmodule Jacob.Bot do
  use Slack

  def handle_connect(slack, state) do
    IO.puts "Connected as #{slack.me.name}"
    {:ok, state}
  end

  def handle_event(message = %{type: "message"}, slack, state) do
    case message |> personal_mention?(slack) do
      true -> process_personal_message message, slack
      false -> :nothing
    end

    {:ok, state}

    # result =
    # [&process_dlls/3, &process_service_op/3, &dummy/3]
    # |> Enum.reduce_while(message.text, fn f, msg -> wrap_func(f, msg, message.channel, slack) end)
    # # case ~r/(?<name>[-.0-9a-zA-Z]+)\.dll\b/U  |> Regex.scan(message.text) do
    # #   nil -> nil
    # #   [_h1|_t1] = list ->
    # #     list |> Enum.map(fn [_x,x|_t] -> {x, "gacutil /l #{x}" |> String.to_char_list |> :os.cmd} end)
    # #   _ -> nil
    # # end
    # response =
    # case result do
    #   :nothing -> "I've got nothing for you, sir."
    #   nil -> "I've got nothing to do sir!"
    #   r -> "My response for you, sir:\r\n#{r}"
    #   # [_h2|_t2] = list ->
    #   #   for {x, res} <- list, into: "", do: "#{x} --> #{res}\r\n"
    # end
    # # response = "Hello Sir!"
    # send_message(response, message.channel, slack)
    # {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, text, channel}, slack, state) do
    IO.puts "Sending your message, captain!"

    send_message(text, channel, slack)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}

  # Private functions

  defp wrap_func(func, msg, channel, slack) do
    case func.(msg, channel, slack) do
      nil -> {:cont, msg}
      x -> {:halt, x}
    end
  end

  def process_dlls(msg, _channel, _slack) do
    case ~r/(?<name>[-.0-9a-zA-Z]+)\.dll\b/U |> Regex.scan(msg) do
      nil -> nil
      [_h1|_t1] = list ->
        list |> Enum.map(fn [_x,x|_t] -> "gacutil /l #{x}" |> String.to_char_list |> :os.cmd end)
      _ -> nil
    end
  end

  def process_service_op(msg, channel, slack) do
    case ~r/(?P<1verb>(start|stop))\W*service\W*(?P<2service_name>[\w\$`]+)/ |> Regex.run(msg, capture: :all_names) do
      [verb,service_name|_t] ->
        spawn __MODULE__, :run_service_op, [service_name, verb, channel, slack]
        "Im #{verb}ing #{service_name} service"
      _ -> nil
    end
  end

  defp extract_number(s), do: ~r/[0-9]+/ |> Regex.run(s) |> hd

  def run_service_op(service_name, action_verb, channel, slack) do
    res = apply Services, "#{action_verb}_service" |> String.to_atom, [service_name]
    case res |> to_string |> extract_number |> String.to_integer do
      0 ->
        send_message "Service #{service_name} is #{action_verb}ing...", channel, slack
        case :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, Services.get_target_status(action_verb), channel, slack] do
          {:ok, _ref} -> send_message "I'll be notifying you about the service state every 5 seconds", channel, slack
          {:error, reason} -> send_message "Sorry, something went wrong and I won't be able to report to you on the service status updates", channel, slack
        end
      x -> send_message "#{action_verb} of service #{service_name} exited with code #{x}", channel, slack
    end
    :ok
  end

  def check_service_status(service_name, target_status, channel, slack) do
    case Services.get_service_state service_name do
      ^target_status ->
        send_message "Service #{service_name} is now #{target_status}", channel, slack
        :done
      state ->
        send_message "Service #{service_name} is #{state}", channel, slack
        :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, target_status, channel, slack]
    end
  end

  defp dummy(_msg, _channel, _slack), do: :nothing

  defp personal_mention?(message, slack),
    do: String.contains?(message, slack.me.id)
    or  message.channel == Slack.Lookups.lookup_direct_message_id(message.user)

  defp process_personal_message(message, slack) do
    result =
    [&process_dlls/3, &process_service_op/3, &dummy/3]
    |> Enum.reduce_while(message.text, fn f, msg -> wrap_func(f, msg, message.channel, slack) end)
    # case ~r/(?<name>[-.0-9a-zA-Z]+)\.dll\b/U  |> Regex.scan(message.text) do
    #   nil -> nil
    #   [_h1|_t1] = list ->
    #     list |> Enum.map(fn [_x,x|_t] -> {x, "gacutil /l #{x}" |> String.to_char_list |> :os.cmd} end)
    #   _ -> nil
    # end
    response =
    case result do
      :nothing -> "I've got nothing for you, sir."
      nil -> "I've got nothing to do sir!"
      r -> "My response for you, sir:\r\n#{r}"
      # [_h2|_t2] = list ->
      #   for {x, res} <- list, into: "", do: "#{x} --> #{res}\r\n"
    end
    # response = "Hello Sir!"
    send_message(Slack.Lookups.lookup_user_name(message.user, slack) <> response, message.channel, slack)
  end

end
