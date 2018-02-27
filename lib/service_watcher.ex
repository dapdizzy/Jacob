defmodule Deprecated.Service.Watcher do
  def start_watching do
    # IO.puts "Jacob is mapped to #{Slack |> Process.whereis |> inspect}"
    IO.puts "Registered processed:"
    Process.registered
      |> Enum.each(&(IO.puts "#{&1}"))
    case Application.get_env(:jacob_bot, :services_to_watch)  do
      nil -> :nothing
      [_h|_t] = list -> list |> watch
    end
  end

  def watch(services, watch_interval \\ 5000, expiration_period \\ :infinity) when services |> is_list do
    notify_destination = Application.get_env(:jacob_bot, :notify_destination)
    IO.puts "notify destination: #{notify_destination}"
    services
      |> Enum.each(
        fn {service, mode} ->
          ok_state = mode |> Services.mode_to_service_state
          interim_state = mode |> Services.mode_to_interim_state
          service_name_expanded = service |> Jacob.Bot.expand_service_name
          Helpers.spawn_process  __MODULE__, :watch_service, [service_name_expanded, mode, ok_state, nil, notify_destination, watch_interval, expiration_period], true
          send_message "Watching *#{service_name_expanded}* to be *#{mode}*", notify_destination
          # case service_name_expanded |> Services.get_service_state do
          #   ^ok_state ->
          #     :ok
          #   ^interim_state ->
          #     send_message "Service *#{service_name_expanded}* is now *#{Jacob.Bot.ingify interim_state}*", notify_destination
          #
          #   other_state ->
          #     # ...
          # end
        end
      )
  end

  def start_url_warmup do
    urls = Application.get_env(:jacob_bot, :urls_to_warmup)
    warmup_interval = Application.get_env(:jacob_bot, :url_warmup_interval_mins) || 10
    url_to_job_map =
      for url <- urls, into: %{}, do: {url, create_warmup_job(url, warmup_interval)}
    Agent.start_link(fn -> url_to_job_map end, name: :urls_warmup_holder)
    :done
  end

  defp create_warmup_job(url, timeout_mins) do
    {:ok, pid} = TimerJob.start_link __MODULE__, :warmup_url, [url], timeout_mins * 60 * 1_000, true
    pid
  end

  def warmup_url(url) do
    IO.puts "Going to warmup url #{url}..."
    res = HTTPoison.get! url
    IO.puts "Response started with\r\n#{String.slice(0..50)}..."
    IO.puts "Done warmup of #{url}"
  end

  def watch_service(service_name, expected_state, _prev_state, notify_destination, watch_interval, expiration_period) when expiration_period |> is_integer and expiration_period <= 0 do
    watch_interval |> :timer.apply_after(__MODULE__, :watch_service, [service_name, expected_state, nil, notify_destination, watch_interval])
  end

  def watch_service(service_name, mode, expected_state, prev_state, notify_destination, watch_interval \\ 5000, expiration_period \\ :infinity) do
    if Helpers.is_forzen? do
      IO.puts "exiting from watch_service due to bot being frozen"
      # Here the actual child process shutdown occurs
      # Thats why the main process always reports zero child processes were stopped.
      exit(:shutdown)
    end
    interim_state = mode |> Services.mode_to_interim_state
    case service_name |> Services.get_service_state do
      ^expected_state ->
        unless !prev_state || prev_state == expected_state do
          send_message "Service *#{service_name}* is now *#{expected_state}*", notify_destination
        end
        :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, expected_state, notify_destination, watch_interval, :infinity]
      ^interim_state ->
        if !prev_state || prev_state != interim_state do
          send_message "Service *#{service_name}* is now *#{Jacob.Bot.ingify interim_state}*", notify_destination
        end
        :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, interim_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != interim_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
      other_state ->
        if !prev_state || prev_state != other_state do
          send_message "Service *#{service_name}* is now *#{Jacob.Bot.ingify other_state}*", notify_destination
          action_verb = mode |> Services.mode_to_action_verb
          send_message "Trying to *#{action_verb}* service *#{service_name}*", notify_destination
          action = "#{action_verb}_service" |> String.to_atom
          res = apply Services, action, [service_name]
          send_message "*#{action}* exited with code *#{res}*", notify_destination
        end
        :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, other_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != other_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
    end
  end

  def send_message(message, destination) do
    Jacob |> send({:send_message, message, destination})
  end
end
