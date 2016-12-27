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

    Helpers.spawn_process(fn -> :timer.apply_after 5000, Service.Watcher, :start_watching, [] end, true)

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
  def handle_info({:send_message, message, destination}, slack, state) do
    IO.puts "Resolving recepient #{destination}"
    channel =
    [&Slack.Lookups.lookup_direct_message_id/2, &Slack.Lookups.lookup_channel_id/2, fn _arg, _slack -> nil end]
      |> Enum.reduce_while(destination, fn f, arg -> f |> wrap_func("@" <> arg, slack) end)
    case channel do
      nil ->
        IO.puts "Your message could not be send. Destination *#{destination}* could not be resolved."
      _ -> send_message message, channel, slack
    end
    {:ok, state}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason} , _slack, state) do
    child_processes = Helpers.get_child_processes
    new_child_processes =
    case child_processes |> Enum.any?(
      fn
        {^pid, ^ref, _definition, _is_restartable} ->
          true
        {_pid, _ref, _definition, _is_restartable} ->
          false
      end) do
      true ->
        child_processes |> Enum.filter(
          fn
            {^pid, ^ref, _definition, _is_restartable} ->
              false
            {_pid, _ref, _definition, _is_restartable} ->
              true
          end
        )
      false ->
        child_processes
    end
    Helpers.set_child_processes new_child_processes

    {:ok, state}
  end

  def handle_info(_, _, state), do: {:ok, state}

  # Private functions

  defp wrap_func(func, arg, slack) do
    case func.(arg, slack) do
      nil -> {:cont, arg}
      x -> {:halt, x}
    end
  end

  defp wrap_func(func, msg, channel, slack) do
    case func.(msg, channel, slack) do
      nil -> {:cont, msg}
      x -> {:halt, x}
    end
  end

  def process_how_is_he_doing(msg, channel, slack) do
    env = Application.get_env(:jacob_bot, :env)
    rex = "how\\s+[\\w\\W]*\\s*#{env}\\s+(?<service_name>\\w+)\\s+doing"
      |> Regex.compile!([:caseless, :ungreedy])
    IO.puts "Env: #{env}, rex: #{inspect rex}"
    IO.puts "Analyzing msg: #{msg}"
    case rex |> Regex.named_captures(msg) do
      nil -> nil
      %{"service_name" => service_name} ->
        service_name_expanded = service_name |> expand_service_name
        service_state = service_name_expanded |> Services.get_service_state
        "Service *#{service_name_expanded}* is now *#{service_state}*"
    end
  end

  # TODO: code it!
  def freeze_bot(msg, _channel, _slack) do
    env = Application.get_env(:jacob, :env)
    case "#{env}\\s+bot\\s+freeze" |> Regex.compile!([:caseless]) |> Regex.match?(msg) do
      true ->
        Helpers.freeze!
        processes_killed = Helpers.kill_child_processes
        Helpers.update_child_processes!
        "Bot is now *frozen*, *#{processes_killed}* child processes were killed"
      false ->
        nil
    end
  end

  def unfreeze_bot(msg, _channel, _slack) do
    env = Application.get_env(:jacob, :env)
    case "#{env}\\s+bot\\s+unfreeze" |> Regex.compile!([:caseless]) |> Regex.match?(msg) do
      true ->
        Helpers.unfreeze!
        processes_restarted = Helpers.restart_child_processes! |> Enum.count
        "Bot has been *unfreezed*. *#{processes_restarted}* child processes have been restarted."
      false ->
        nil
    end
  end

  def restart_service(msg, channel, slack) do
    env = Application.get_env(:jacob_bot, :env)
    case ~r/restart\s+(?<service_name>\w+)\s+(?<env_name>\w+)\s*((?<hours>\d{2})\:(?<minutes>\d{2}))?/i |> Regex.named_captures(msg) do
      nil -> nil
      %{"env_name" => ^env} = map ->
        Helpers.spawn_process __MODULE__, :restart_service!, [map["service_name"], channel, slack, (if map["hours"] != "" || map["minutes"] != "", do: {map["hours"] |> String.to_integer, map["minutes"] |> String.to_integer})], false
        if map["hours"] == "" && map["minutes"] == "" do
          ~s|Trying to restart *#{map["service_name"]}* service|
        else
          ~s|Service *#{map["service_name"]}* restart scheduled at *#{map["hours"]}:#{map["minutes"]}*|
        end
      _ -> :silent
    end
  end

  def restart_service!(service_name, channel, slack, schedule \\ nil) do
    case schedule do
      nil ->
        service_name
          |> build_service_op_seq
          |> proceed_operations(channel, slack, false)
        :yepp! # restart right away
      {h, m} ->
        offset_ms(h, m)
          |> :timer.apply_after(__MODULE__, :restart_service!, [service_name, channel, slack, nil])
        :done # restart at the given time h:m
    end
  end

  defp offset_ms(hours, minutes) do
    {date, _time} = timestamp = :os.timestamp |> :calendar.now_to_local_time
    IO.puts "timestamp #{inspect timestamp}"
    diff =
    (({date, {hours, minutes, 0}} |> :calendar.datetime_to_gregorian_seconds |> Kernel.*(1000)) -
    (timestamp |> :calendar.datetime_to_gregorian_seconds |> Kernel.*(1000)))
    IO.puts "Diff: #{diff}"
    diff
  end

  def service_depends_on(service_name) do
    depends_on_map =
    (for {key, value} <- Application.get_env(:jacob_bot, :service_deps),
      into: [], do: for val <- value, into: [], do: {val, key})
      |> List.flatten
      |> Enum.reduce(%{},
          fn {dependency, dependant}, acc ->
            acc |> Map.update(dependency, [dependant], &([dependant|&1]))
          end)
    depends_on_map[service_name]
    # for {dependency, dependant} <- depends_on_list,
    #   into: %{}
    #
    #   |> Enum.reduce(%{},
    #       fn {key, value}, acc ->
    #         value |> Enum.reduce(acc,
    #           fn dep, acc ->
    #
    #           end)  acc |> Map.put(any(), any())  end)
    # for {key, val} <- Application.get_env(:jacob_bot, :service_deps),
    #   into: %{}, do: val |> Enum.reduce(%{}, &({&1, key}))
  end

  def build_service_op_seq(service_name) do
    service_name_expanded = service_name |> expand_service_name
    services =
    case service_name |> service_depends_on do
      nil ->
        [service_name_expanded]
      [_h|_t] = list ->
        expanded_list =
        (for item <- list,
          into: [],
          do: item |> expand_service_name)
        [service_name_expanded|expanded_list]
          |> Enum.reverse
    end
    services |> service_list_to_op_seq
  end

  defp service_list_to_op_seq([_h|_t] = list) do
    (for item <- list, into: [], do: {"stop", item |> expand_service_name})
    ++
    (for item <- Enum.reverse(list), into: [], do: {"start", item |> expand_service_name})
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
    case ~r/(?P<1verb>(start|stop))\W*service\W*(?P<2service_name>[\w\$`]+)/i |> Regex.run(msg, capture: :all_names) do
      [verb,service_name|_t] ->
        service_name = service_name |> expand_service_name
        if !check_service_in_target_state service_name, verb, channel, slack do
          Helpers.spawn_process __MODULE__, :run_service_op, [service_name, verb, channel, slack, ~r/silent/ |> Regex.match?(msg)]
          "Im #{verb}ing #{service_name} service"
        end
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
      # :ets.insert :notifications, channel, notification_options |> Map.put(:stop, true)
    end
  end

  def process_cancel(msg, channel, slack) do
    if (~r/cancel/ |> Regex.match?(msg)) && (:notifications |> Helpers.ets_exist?) do
      notification_options =
      case :ets.lookup :notifications, channel do
        [%{} = map] -> map
        _ -> %{}
      end
      # :ets.insert :notifications, channel, notification_options |> Map.put(:cancel, true)
    end
  end

  defp extract_number(s), do: ~r/[0-9]+/ |> Regex.run(s) |> hd

  def expand_service_name(service_name) do
    case Application.get_env :jacob_bot, :service_aliases, nil do
      %{} = map -> map |> Map.get(service_name |> String.downcase, service_name)
      nil -> service_name
    end
  end

  def check_service_in_target_state(service_name, action_verb, channel, slack) do
    target_status = Services.get_target_status(action_verb)
    case service_name |> Services.get_service_state do
      ^target_status ->
        send_message "Service *#{service_name}* is already *#{target_status}*", channel, slack
        :ok
      _ -> nil
    end
  end

  defp proceed_operations([], _channel, _slack, _silent), do: :done

  defp proceed_operations([{action_verb, service_name}|t] = operations_list, channel, slack, silent \\ false) do
    run_service_op service_name, action_verb, channel, slack, silent, t
  end

  def run_service_op(service_name, action_verb, channel, slack, silent \\ false, operations_list \\ []) do
    action_verb = action_verb |> String.downcase
    target_status = Services.get_target_status(action_verb)
    res = apply Services, "#{action_verb}_service" |> String.to_atom, [service_name]
    case res |> to_string |> extract_number |> String.to_integer do
      0 ->
        state_reached =
        case service_name |> Services.get_service_state do
          ^target_status -> :yes
          _ -> :no
        end
        case state_reached do
          :yes ->
            send_message "Service *#{service_name}* is now *#{target_status}*", channel, slack
            proceed_operations operations_list, channel, slack, silent
          _ ->
            send_message "Service *#{service_name}* is #{ingify action_verb}...", channel, slack
            case :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, target_status, channel, slack, silent, operations_list] do
              {:ok, _ref} -> if !silent, do: send_message "I'll be notifying you about the service state every 5 seconds", channel, slack
              {:error, _reason} -> send_message "Sorry, something went wrong and I won't be able to report to you on the service status updates", channel, slack
            end
        end
      x -> send_message "#{action_verb} of service #{service_name} exited with code #{x}", channel, slack
    end
    :ok
  end

  def ingify(str), do: unless str |> String.downcase |> String.ends_with?(["ing", "ed"]), do: (if ~r/[^p]{1}p$/ |> Regex.match?(str), do: str <> "p", else: str) <> "ing", else: str

  def check_service_status(service_name, target_status, channel, slack, silent \\ false, operations_list \\ []) do
    case Services.get_service_state service_name do
      ^target_status ->
        send_message "Service *#{service_name}* is now *#{target_status}*", channel, slack
        proceed_operations operations_list, channel, slack, silent
      state ->
        if !silent do
          send_message "Service *#{service_name}* is *#{ingify state}*", channel, slack
        end
        :timer.apply_after 5000, __MODULE__, :check_service_status, [service_name, target_status, channel, slack, silent, operations_list]
    end
  end

  defp dummy(_msg, _channel, _slack), do: :nothing

  defp has_mention?(text), do: ~r/\<\@\w+\>/ |> Regex.match?(text)

  defp personal_mention?(message, slack),
    do: String.contains?(message.text, slack.me.id)
    or  message.channel == Slack.Lookups.lookup_direct_message_id(message.user, slack)

  defp process_personal_message(message, slack) do
    result =
    [&freeze_bot/3, &unfreeze_bot/3, &restart_service/3, &process_how_is_he_doing/3, &process_dlls/3, &process_service_op/3, &dummy/3]
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
    if result != :silent do
      send_message(Slack.Lookups.lookup_user_name(message.user, slack) <> " " <> response, message.channel, slack)
    end
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

  def read_token do
    filename = "Key" |> Cipher.encrypt
    entrypted = filename |> File.read!
    token = entrypted |> Cipher.decrypt
  end

end
