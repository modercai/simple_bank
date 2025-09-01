# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bank, :scopes,
  user: [
    default: true,
    module: Bank.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Bank.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :bank,
  ecto_repos: [Bank.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :bank, BankWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BankWeb.ErrorHTML, json: BankWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Bank.PubSub,
  live_view: [signing_salt: "ADVOtnhg"]

#momo
config :bank, :mtn_momo,
  base_url: "https://sandbox.momodeveloper.mtn.com",
  subscription_key: "70a027b279b6428ca26edd3211642ae1",
  target_environment: "sandbox",
  currency: "EUR",
  # for token generation
  api_user: "b7e38eb0-48de-4c48-8542-91e4baa3d555",
  api_key: "749ce8985bd64dc3ac6d20c41be5ae86"

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :bank, Bank.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  bank: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  bank: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
