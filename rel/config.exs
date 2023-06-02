# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
  # This sets the default release built by `mix release`
  default_release: :default,
  # This sets the default environment used by `mix release`
  default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set(dev_mode: true)
  set(include_erts: false)
  set(config: "config/dev.exs")
  # set included_configs: ["etc/app.config"]
  set(cookie: :test)
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(config: "config/prod.exs")
  set included_configs: ["etc/app.config"]
  set(cookie: :crypto.hash(:sha256, System.get_env("COOKIE") || "pcp") |> Base.encode16 |> String.to_atom)
  # set(pre_configure_hook: "rel/hooks/pre_configure")
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :'unified-chat-gateway' do
  set(version: "2.0.0")

  set(
    applications: [
      :runtime_tools,
      :crypto,
      :live,
      :chat_web,
      :chat,
      :chat_db
    ]
  )

  set(vm_args: "rel/files/vm.args")

  set(
    overlays: [
      # configuration
      {:mkdir, "etc"},
      {:mkdir, "var/"}
    ]
  )
end
