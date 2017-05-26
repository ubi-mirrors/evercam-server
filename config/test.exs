use Mix.Config

config :evercam_media,
  start_camera_workers: false

config :evercam_media,
  start_timelapse_workers: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :evercam_media, EvercamMedia.Endpoint,
  http: [port: 4001],
  server: false,
  email: "evercam.io <env.test@evercam.io>"

# Do not create intercom user in test mode
config :evercam_media, :create_intercom_user, false

# Start spawn process or not
config :evercam_media, :run_spawn, false

# Print only warnings and errors during test
config :logger, level: :warn

config :evercam_media,
  storage_dir: "tmp/storage",
  dummy_auth: "foo:bar"

# Configure your database
config :evercam_media, EvercamMedia.Repo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [
    {EvercamMedia.Types.JSON.Extension, library: Poison},
    {EvercamMedia.Types.MACADDR.Extension, []},
    {Geo.PostGIS.Extension, library: Geo},
  ],
  username: "postgres",
  password: "postgres",
  database: "evercam_tst",
  pool: Ecto.Adapters.SQL.Sandbox

config :evercam_media, EvercamMedia.SnapshotRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "evercam_tst",
  pool: Ecto.Adapters.SQL.Sandbox

config :exvcr,
  [
    vcr_cassette_library_dir: "test/fixtures/vcr_cassettes",
    custom_cassette_library_dir: "test/fixtures/custom_cassettes",
    filter_sensitive_data: [
      [pattern: "<PASSWORD>.+</PASSWORD>", placeholder: "PASSWORD_PLACEHOLDER"]
    ],
    filter_url_params: false,
    response_headers_blacklist: [],
  ]

