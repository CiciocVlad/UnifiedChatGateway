defmodule Chat.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:websockex, :jason, :chat_db, :poison, :hammer],
      mod: {Chat.Application, []},
      env: []
    ]
  end

  defp deps do
    [
      {:websockex, "~> 0.4.3"},
      {:httpoison, "~> 2.1.0"},
      {:timex, "~> 3.7.9"},
      {:chat_db, [in_umbrella: true]}
    ]
  end
end
