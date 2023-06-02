defmodule ChatWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_web,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ChatWeb.Application, []},
      extra_applications: [:jason, :hammer, :poison, :chat, :phoenix_view]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.2"},
      {:plug_crypto, "~> 1.2"},
      {:plug, "~> 1.14.1"},
      {:cowboy, "~> 2.9.0"},
      {:cors_plug, "~> 3.0.3"},
      {:hammer, "~> 6.1.0"},
      {:remote_ip, "~> 1.1.0"},
      {:chat, [in_umbrella: true]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
