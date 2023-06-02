defmodule ChatDb.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_db,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ChatDb, []},
      env: [
        pools: [
          {:config, [5, 'couchbase05.dev.premiercontactpoint.com:8091', 'config', 'pcp123', 'config']}
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cberl, git: "git@bitbucket.org:pt_hcc/cberl.git", branch: "master_25", manager: :rebar3, override: true}
    ]
  end
end
