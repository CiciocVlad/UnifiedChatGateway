import Config

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

config :live, LiveWeb.Endpoint,
  http: [port: 4010],
  url: [path: "/chat"],
  server: true,
  debug_errors: false,
  render_errors: [accepts: ~w(json)],
  check_origin: false,
  # configuration required for socket - longpoll: secrect key base and pubsub
  secret_key_base: "3fXws7MeTX6XkOYrBI4apLYW7avsgoyKmAjDwpYTFj07JatEmKPS6PCF4AYuqszq",
  socket_longpoll: [
    window_ms: 10_000,
    transport_log: false,
    crypto: [max_age: 1_209_600]
  ],
  live_view: [signing_salt: "FyWoxNB9hnS19QJj"]

config :live, :longpoll,
  window_ms: 10_000,
  crypto: [max_age: 1_209_600]

config :live,
  ws_timeout: 300_000

config :live, images_path: "/var/www/live/priv/static/images"
config :live, svg_path: "/var/www/live/priv/static/svg"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :cors_plug,
  origin: ["*"]

config :chat,
  # seconds
  contact_proc_idle_timeout: 900,
  message_formats: [
    "email",
    "configuration",
    "text",
    "html",
    "form",
    "formResponse",
    "file",
    "image",
    "video"
  ],
  cirrus_base_urls: ["10.3.65.198:21000", "10.3.65.89:21000"],
  # miliseconds
  cirrus_ws_keepalive: 20000,
  rate_limit: 4,
  rate_limit_scale: 1_000,
  rate_limit_white_list: ["127.0.0.1"]

config :chat_db,
  pools: [
    {:config, [5, 'couchbase05.dev.premiercontactpoint.com:8091', 'config', 'pcp123', 'config']}
  ],
  bucket_config: [
    {"tenant", :config},
    {"cluster", :config},
    {"contactPoint", :config},
    {"defaultTimeZone", :config},
    {"form", :config},
    {"attachment", :config},
    {"chatConfiguration", :config}
  ]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/live/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
