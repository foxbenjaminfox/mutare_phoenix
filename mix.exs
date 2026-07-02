defmodule MutarePhoenix.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :mutare_phoenix,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      name: "Mutare Phoenix",
      source_url: "https://github.com/foxbenjaminfox/mutare_phoenix",
      docs: docs()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # The host mutation-testing engine. `mutare_phoenix` implements
      # `Mutare.Mutator` and rides only its public extension points
      # (`Mutare.Transform.Calls`, `Mutare.AST`, `Mutare.Mutator`, the `macros/0`
      # hook). Tests use `Mutare.Test` and `Mutare.AST` for AST parse/render, so no
      # direct `:sourceror` dep is needed. A path dep for local development until
      # `mutare` is published; a consuming project depends on both as `:dev`/`:test` deps.
      {:mutare, path: "../mutare"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # Cache the PLTs outside `_build` so CI (and a `mix clean`) can reuse them. The
  # directory is git-ignored.
  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end

  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end

  defp description do
    "Custom Mutare mutators for Phoenix."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/foxbenjaminfox/mutare_phoenix"},
      files: ~w(lib mix.exs README.md .formatter.exs LICENSE)
    ]
  end
end
