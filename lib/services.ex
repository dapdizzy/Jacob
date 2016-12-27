defmodule Services do
  def start_service(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    File.cwd! |> IO.puts
    ps = ~s/powershell .\\Call-StartService.ps1 '#{service_name}'/
    IO.puts "PS: #{ps}"
    ps
      |> String.to_char_list
      |> :os.cmd
      |> to_string
      |> extract_word
  end

  def stop_service(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    File.cwd! |> IO.puts
    ps = ~s|powershell .\\Call-StopService.ps1 '#{service_name}'|
    IO.puts "PS: #{ps}"
    ps
      |> String.to_char_list
      |> :os.cmd
      |> to_string
      |> extract_word
  end

  def get_service_state(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    File.cwd! |> IO.puts
    ps = ~s/powershell .\\Get-ServiceState.ps1 '#{service_name}'/
    IO.puts  "PS: #{ps}"
    ps
      |> String.to_char_list
      |> :os.cmd
      |> to_string
      |> extract_word
  end

  defp extract_word(s), do: ~r/\w+/ |> Regex.run(s) |> hd

  def get_target_status(verb) do
    case verb |> String.downcase do
      "start" ->
        "Running"
      "stop" ->
        "Stopped"
      _ -> raise "Unexpected verb #{verb} in a call to Services.get_terget_status function"
    end
  end

  def mode_to_service_state(mode) do
    case mode do
      :on -> "Running"
      :off -> "Stopped"
      _ -> raise "Invalid mode #{mode}"
    end
  end

  def mode_to_action_verb(mode) do
    case mode do
      :on -> "start"
      :off -> "stop"
      _ -> raise "Invalid mode #{mode}"
    end
  end

  def mode_to_interim_state(mode) do
    case mode do
      :on -> "Start"
      :off -> "Stop"
      _ -> raise "Invalid mode #{mode}"
    end
  end
end
