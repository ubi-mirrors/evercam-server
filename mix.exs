defmodule EvercamMedia.Mixfile do
  use Mix.Project

  def project do
    [app: :evercam_media,
     version: "1.0.1",
     elixir: "~> 1.3.0",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:phoenix] ++ Mix.compilers,
     aliases: aliases,
     deps: deps]
  end

  defp aliases do
    [clean: ["clean"]]
  end

  def application do
    [mod: {EvercamMedia, []},
     applications: app_list(Mix.env)]
  end

  defp app_list(:dev), do: [:dotenv, :credo | app_list]
  defp app_list(:test), do: [:dotenv | app_list]
  defp app_list(_), do: app_list
  defp app_list, do: [
    :calendar,
    :cf,
    :comeonin,
    :con_cache,
    :connection,
    :cors_plug,
    :cowboy,
    :ecto,
    :geo,
    :httpoison,
    :inets,
    :jsx,
    :mailgun,
    :meck,
    :phoenix,
    :phoenix_ecto,
    :phoenix_html,
    :phoenix_pubsub,
    :porcelain,
    :postgrex,
    :quantum,
    :runtime_tools,
    :timex,
    :tzdata,
    :uuid,
    :xmerl,
    :html_sanitize_ex,
  ]

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  defp deps do
    [
      {:calendar, "~> 0.16.0"},
      {:comeonin, "~> 2.4"},
      {:con_cache, "~> 0.11.1"},
      {:cors_plug, "~> 1.1"},
      {:cowboy, "~> 1.0"},
      {:credo, github: "rrrene/credo", only: :dev},
      {:dotenv, "~> 2.1.0", only: [:dev, :test]},
      {:ecto, "~> 2.0.2"},
      {:exrm, github: "bitwalker/exrm"},
      {:geo, "~> 1.1"},
      {:httpoison, "~> 0.11.1"},
      {:jsx, "~> 2.8.0", override: true},
      {:mailgun, github: "evercam/mailgun"},
      {:phoenix, "~> 1.2.0-rc.1"},
      {:phoenix_ecto, "~> 3.0.0"},
      {:phoenix_html, "~> 2.6"},
      {:porcelain, github: "alco/porcelain"},
      {:postgrex, ">= 0.11.2"},
      {:quantum, github: "c-rack/quantum-elixir"},
      {:uuid, "~> 1.1"},
      {:relx, github: "erlware/relx", override: true},
      {:erlware_commons, "~> 0.22.0", override: true},
      {:cf, "~> 0.2.1", override: true},
      {:exvcr, "~> 0.7", only: :test},
      {:meck,  "~> 0.8.4", override: :true},
      {:html_sanitize_ex, "~> 1.0.0"},
    ]
  end
end
