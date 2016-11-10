defmodule Jacob.Bot do
  use Slack

  def handle_connect(slack, state) do

    dir = "C:/Txt"
    IO.puts "cwd is #{dir}"
    dir |> File.mkdir_p!
    file_name = dir |> Path.join("slack_state.txt")
    IO.puts "filename is #{file_name}"
    file_name |> File.write!(slack |> inspect(limit: 100))
    IO.puts "Flushed Slack into #{file_name}"
    file_name = dir |> Path.join("bot_state.txt")
    file_name |> File.write!(state |> inspect(limit: 100))
    IO.puts "Flushed Bot state into #{file_name}"

    IO.puts "Connected as #{slack.me.name}"
    # raise "Exiting right away..."

    {:ok, state}
  end

  def handle_event(message = %{type: "message"}, slack, state) do

    dir = Application.get_env(:jacob_bot, :cwd)
    file_name = dir |> Path.join("Messages.txt")
    txt = "\r\n" <> (if message |> personal_mention?(slack), do: "Personal", else: "General")
    <> " message:\r\n\r\n#{message |> inspect}"
    file_name |> File.write!(txt, [:append])

    result =
    case message |> personal_mention?(slack) do
      true  -> process_personal_message message, slack
      false -> :nothing
    end

    # Try to process "Thank you" message if :nothing was processed so far
    # case result do
    #   :nothing ->
    #     process_thank_you message, slack, state
    #   _ -> :nothing
    # end

    {:ok, state |> Map.put(message.channel, {message.user, message.text})}

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
        spawn __MODULE__, :run_service_op, [service_name, verb, channel, slack, ~r/silent/ |> Regex.match?(msg)]
        "Im #{verb}ing #{service_name} service"
      _ -> nil
    end
  end

  def process_stop(msg, channel, slack) do
    if (~r/stop/ |> Regex.match(msg)) && (:notifications |> Helpers.ets_exist?) do
      notification_options =
      case :ets.lookup :notifications, channel do
        [%{} = map] -> map
        _ -> %{}
      end
      :ets.insert :notifications, channel, notification_options |> Map.put(:stop, true)
    end
  end

  def process_cancel(msg, channel, slack) do
    if (~r/cancel/ |> Regex.match?(msg)) && (:notifications |> Helpers.ets_exist?) do
      notification_options =
      case :ets.lookup :notifications, channel do
        [%{} = map] -> map
        _ -> %{}
      end
      :ets.insert :notifications, channel, notification_options |> Map.put(:cancel, true)
    end
  end

  defp extract_number(s), do: ~r/[0-9]+/ |> Regex.run(s) |> hd

  defp expand_service_name(service_name) do
    case Application.get_env :jacob_bot, :service_aliases, nil do
      %{} = map -> map |> Map.get(service_name |> String.downcase, service_name)
      nil -> service_name
    end
  end

  def run_service_op(service_name, action_verb, channel, slack, silent \\ false) do
    service_name = service_name |> expand_service_name
    res = apply Services, "#{action_verb}_service" |> String.to_atom, [service_name]
    case res |> to_string |> extract_number |> String.to_integer do
      0 ->
        target_status = Services.get_target_status(action_verb)
        state_reached =
        case service_name |> Services.get_service_state do
          ^target_status -> :yes
          _ -> :no
        end
        case state_reached do
          :yes ->
            send_message "Service *#{service_name}* is now *#{target_status}*", channel, slack
          _ ->
            send_message "Service #{service_name} is #{action_verb}ing...", channel, slack
            case :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, target_status, channel, slack, silent] do
              {:ok, _ref} -> if !silent, do: send_message "I'll be notifying you about the service state every 5 seconds", channel, slack
              {:error, _reason} -> send_message "Sorry, something went wrong and I won't be able to report to you on the service status updates", channel, slack
            end
        end
      x -> send_message "#{action_verb} of service #{service_name} exited with code #{x}", channel, slack
    end
    :ok
  end

  def check_service_status(service_name, target_status, channel, slack, silent \\ false) do
    case Services.get_service_state service_name do
      ^target_status ->
        send_message "Service #{service_name} is now #{target_status}", channel, slack
        :done
      state ->
        if !silent do
          send_message "Service #{service_name} is #{state}", channel, slack
        end
        :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, target_status, channel, slack, silent]
    end
  end

  defp dummy(_msg, _channel, _slack), do: :nothing

  defp has_mention?(text), do: ~r/\<\@\w+\>/ |> Regex.match?(text)

  defp personal_mention?(message, slack),
    do: String.contains?(message.text, slack.me.id)
    or  message.channel == Slack.Lookups.lookup_direct_message_id(message.user, slack)

  defp process_personal_message(message, slack) do
    result =
    [&process_dlls/3, &process_service_op/3, &dummy/3]
    |> Enum.reduce_while(message.text, fn f, msg -> wrap_func(f, msg, Slack.Lookups.lookup_direct_message_id(message.user, slack), slack) end)
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
      r -> r # "My response for you, sir:\r\n#{r}"
      # [_h2|_t2] = list ->
      #   for {x, res} <- list, into: "", do: "#{x} --> #{res}\r\n"
    end
    # response = "Hello Sir!"
    send_message(Slack.Lookups.lookup_user_name(message.user, slack) <> " " <> response, message.channel, slack)
  end

  defp process_thank_you(message, slack, state) do
    {has_thank_you, language} = message.text |> has_thank_you?
    cond do
      has_thank_you
      && ((!(message.text |> has_mention?)) || (message.text |> personal_mention?(slack)))
      && (state |> Map.get(message.channel, nil) |> is_my_message?(slack)) ->
        send_message Slack.Lookups.lookup_user_name(message.user, slack) <> " " <> you_are_welcome_text(language), message.chanel, slack
      true -> :nothing
    end
  end

  defp is_my_message?({my_id, _}, %{me: %{id: my_id}} = _slack), do: true
  defp is_my_message?(_, _slack), do: false

  defp has_thank_you?(text) when text |> is_binary do
    text = text |> String.downcase
    cond do
      text |> has_english_thank_you? -> {true, :english}
      text |> has_russian_thank_you? -> {true, :russian}
      text |> has_other_thank_you?   -> {true, :unknown}
      true -> {false, nil}
    end
  end
    #  ~r/(thank\s*you|10x|tnx|thanks|спасибо|пасибо|пасиба|спс|псб)/ |> Regex.match?(text)
  defp has_thank_you?(_), do: false

  defp has_english_thank_you?(text) do
    ~r/(thank\s*you|tnx|thanks)/ |> Regex.match?(text)
  end

  defp has_russian_thank_you?(text) do
    ~r/(спасибо|пасибо|пасиба|спс|псб)/ |> Regex.match?(text)
  end

  defp has_other_thank_you?(text) do
    ~r/(10x)/ |> Regex.match?(text)
  end

  defp you_are_welcome_text(:russian) do
    "На здоровье!"
  end

  defp you_are_welcome_text(:english) do
    "You are welcome!"
  end

  defp you_are_welcome_text(_language) do
    "請"
  end

end
