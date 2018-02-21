defmodule Jacob.Mixfile do
  use Mix.Project

  def project do
    [app: :jacob_bot,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :slack],
     mod: {Jacob, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:slack, "~> 0.9.1"},
      {:cipher, ">= 1.2.0"},
      # {:rabbitmq_receiver, "~> 0.1.2", runtime: false}
      {:rabbitmq_receiver, "~> 0.1.5"}, # Potential breaking change here.
      # {:rabbitmq_sender, "~> 0.1.6"},
      {:rabbitmq_sender, "~> 0.1.7"}
    ]
  end
end
