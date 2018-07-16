defmodule ServiceSupervisorsManagement do
  def process_management_command(%ReceiverMessage{payload: command_raw}) do
    command_map = command_raw |> Poison.decode!
    command = command_map["command"]
    args = command_map["args"]
    case command do
      "register" ->
        identity = args["identity"]
        IO.puts "Service supervisor with identity #{identity} was registered"
    end
  end
end
