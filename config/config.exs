# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

  config :jacob_bot, scripts_folder: "C:/AX/BuildScripts",
  cwd: "C:/Txt",
  aos: "aos",
  env: "stage",
  service_aliases:
    %{
      # "kafka" => "KafkaProxyConnector",
      "aos" => "AOS60$02",
      "cloud_client" => "WAX3PL Stage Cloud Client"
    },
  service_deps:
    %{
      # "kafka" => ["aos"],
      "cloud_client" => ["aos"]
    },
  services_to_watch:
    [
      # {"kafka", :on},
    {"aos", :on}, {"cloud_client", :on}],
  notify_destination:
    "dpyatkov",

  urls_to_warmup:
    [
      "https://warm-savannah-34152.herokuapp.com/"
    ],
  url_warmup_interval_mins: 20

  config :cipher,
    keyphrase: "testiekeyphraseforcipher",
    ivphrase: "testieivphraseforcipher",
    magic_token: "magictoken"

  config :rabbitmq_sender,
    rabbit_options:
      [
        host: "localhost",
        username: "hunky",
        virtual_host: "/",
        password: "hunky"
      ]
      # [
      #   host: "rhino.rmq.cloudamqp.com",
      #   username: "ftudzxhj",
      #   virtual_host: "ftudzxhj",
      #   password: "FojWUx6kp6-zFDtDT0tCkmFRQhcP7t-a"
      # ]
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
