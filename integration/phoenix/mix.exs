defmodule MutarePhoenixIntegration.MixProject do
  use Mix.Project

  def project do
    [
      app: :mutare_phoenix_integration,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: [
        {:mutare_phoenix, path: "../.."},
        {:phoenix, "~> 1.8.0"},
        {:phoenix_live_view, "~> 1.2"}
      ]
    ]
  end
end
