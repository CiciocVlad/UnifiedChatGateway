defmodule PCPChat.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        unified_chat_gateway: [
          version: "1.0.0",
          applications: [
            live: :permanent,
            chat_web: :permanent,
            chat: :permanent,
            chat_db: :permanent
          ],
          cookie: "pcp"
        ]
      ]
    ]
  end

  defp deps do
    [
      # release
      {:distillery,
       git: "git@bitbucket.org:pt_hcc/distillery.git", branch: "master", runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:poison, "~> 5.0"},
      {:poolboy, "~> 1.5", override: true},
      {:phoenix_view, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
