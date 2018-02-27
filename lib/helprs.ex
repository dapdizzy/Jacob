defmodule Helpers do
  def ets_exist?(ets_name) do
    case :ets.info(ets_name) do
      :undefined -> false
      _ -> true
    end
  end

  def ets_lookup(table, key, default_value) when table |> is_atom  do
    IO.puts "Trying to lookup #{key} from #{table}"
    case table |> :ets.lookup(key) do
      [{^key, value}] -> value
      [] -> default_value
    end
  end

  def ets_insert(table, key, value) when table |> is_atom do
    IO.puts "Inserting #{key} and #{inspect value} into #{table}"
    ret = table |> :ets.insert({key, value})
    IO.puts "Done inserting!"
    ret
  end

  def spawn_process(function, is_restartable \\ false) when is_restartable |> is_boolean do
    pid = spawn(function)
    IO.puts "pid #{inspect pid} assigned for #{inspect function}"
    add_to_child_processes pid, function, is_restartable
  end

  def spawn_process(m, f, a, is_restartable \\ false) when is_restartable |> is_boolean do
    pid = spawn(m, f, a)
    definition = {m, f, a}
    IO.puts "pid #{inspect pid} assigned for definition #{inspect definition}"
    add_to_child_processes pid, {m, f, a}, is_restartable
  end

  defp add_to_child_processes(pid, definition, is_restartable) when is_restartable |> is_boolean do
    ref = pid |> Process.monitor
    IO.puts "Monitoring reference #{inspect ref} assigned for pod #{inspect pid}"
    add_to_child_processes pid, ref, definition, is_restartable
  end

  defp add_to_child_processes(pid, ref, definition, is_restartable) when is_restartable |> is_boolean do
    child_processes = :jacob_ets |> ets_lookup(:child_processes, [])
    IO.puts "Current child processes: #{inspect child_processes}"
    :jacob_ets |> ets_insert(:child_processes, [{pid, ref, definition, is_restartable}|child_processes])
    :ok
  end

  defp restart_from_definition(definition) do
    pid =
    case definition do
      {m, f, a} ->
        spawn m, f, a
      function when function |> is_function ->
        spawn function
    end
    ref = Process.monitor(pid)
    {pid, ref, definition, true}
  end

  def get_child_processes do
    :jacob_ets |> ets_lookup(:child_processes, [])
  end

  def set_child_processes(child_processes) do
    :jacob_ets |> ets_insert(:child_processes, child_processes)
    :ok
  end

  def kill_child_processes do
    get_child_processes
      |> Enum.reduce(0,
        fn {pid, _ref, _definition, _is_restartable}, counter ->
          if pid |> Process.alive? do
            pid |> Process.exit(:kill)
            counter + 1
          else
            counter
          end
        end)
  end

  def restart_child_processes! do
    get_child_processes
      |> Enum.filter_map(
        fn {_pid, _ref, _definition, is_restartable} -> is_restartable end,
        fn {_pid, _ref, definition, _is_restartable} -> definition |> restart_from_definition end)
  end

  def update_child_processes! do
    get_child_processes
      |> Enum.filter(fn {_pid, _ref, _definition, is_restartable} -> is_restartable end)
      |> set_child_processes
  end

  def is_forzen? do
    :jacob_ets |> ets_lookup(:frozen, false)
  end

  def freeze! do
    :jacob_ets |> ets_insert(:frozen, true)
  end

  def unfreeze! do
    :jacob_ets |> ets_insert(:frozen, false)
  end

  def handle_send_to_slack_request(%ReceiverMessage{payload: request}) do
    case request |> String.split("::", parts: 2) do
      [message, destination|_t] ->
        Jacob |> Jacob.Bot.send_message_to_slack(message, destination)
        IO.puts "Submitting a message [#{message}] to #{destination} via our own Slack Bot Jacob"
      _ ->
        IO.puts "Unable to parse incoming request [#{request}]"
    end
  end

  def handle_remote_execution_reply(%ReceiverMessage{payload: payload, correlation_id: correlation_id}) do
    if correlation_id |> PendingRequests.has_pending_request? do
      Jacob |> Jacob.Bot.send_message_to_slack("Reply for request with correlation id *#{correlation_id}* arrived:\n*#{payload}*", "dpyatkov")
      PendingRequests.remove_pending_request correlation_id
    else
      IO.puts "Pending request with correlation id [#{correlation_id}] is not found."
    end
    # Jacob |> Jacob.Bot.send_message_to_slack("Reply for request with correlation id *#{correlation_id}* arrived:\n*#{payload}*", "dpyatkov")
  end

end
