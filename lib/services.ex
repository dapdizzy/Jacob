defmodule Services do
  def start_service(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    "powershell .\\Call-StartService.ps1 #{service_name}"
    |> String.to_char_list
    |> :os.cmd
  end

  def stop_service(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    "powershell .\\Call-StopService.ps1 #{service_name}"
    |> String.to_char_list
    |> :os.cmd
  end

  def get_service_state(service_name) do
    scripts_dir = Application.get_env(:jacob_bot, :scripts_folder)
    scripts_dir |> File.cd!
    "powershell .\\Get-ServiceState.ps1 #{service_name}"
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
end
