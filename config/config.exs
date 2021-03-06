# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

  config :jacob_bot, scripts_folder: "C:/AX/BuildScripts",
  cwd: "C:/Txt",
  aos: "aos",
  env: "stage",
  service_aliases:
    %{
      "kafka" => "KafkaProxyConnector",
      "aos" => "AOS60$01",
      "cloud_client" => "MMS RECOMMERCE Cloud 2.0 Client"
    },
  service_deps:
    %{
      "kafka" => ["aos"],
      "cloud_client" => ["aos"]
    },
  services_to_watch:
    [{"kafka", :on}, {"aos", :on}, {"cloud_client", :on}],
  notify_destination:
    "dpyatkov"

  config :cipher,
    keyphrase: "testiekeyphraseforcipher",
    ivphrase: "testieivphraseforcipher",
    magic_token: "magictoken"
# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :jacob_bot, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:jacob_bot, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
