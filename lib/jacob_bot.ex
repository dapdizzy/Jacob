defmodule Jacob do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Slack.Bot, [Jacob.Bot, %{ets_table: :ets.new(:jacob_ets, [:set, :public, :named_table, read_concurrency: true])}, Jacob.Bot.read_token, %{name: Jacob}], id: Jacob),
      worker(
        RabbitMQReceiver,
        [
          [
            host: "localhost",
            username: "hunky",
            virtual_host: "/",
            password: "hunky"
          ],
          "bot_queue",
          Helpers,
          :handle_send_to_slack_request,
          true,
          [name: RabbitMQReceiver]
        ]
      )
      # Define workers and child supervisors to be supervised
      # worker(Jacob.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jacob.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
