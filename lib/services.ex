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
  end
end
