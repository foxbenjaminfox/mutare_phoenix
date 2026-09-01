defmodule Mutare.Phoenix.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/foxbenjaminfox/mutare_phoenix"

  def project do
    [
      app: :mutare_phoenix,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Custom Mutare mutators for the Phoenix request surface — " <>
      "the Plug.Conn / Phoenix.Controller calls a plug or controller action performs."
  end

  # Hex package metadata. The `mutare` core is still a `path:` dependency, so an
  # actual `mix hex.publish` stays blocked until Mutare itself ships to Hex — this
  # section keeps the manifest ready for that day. Only runtime and doc artifacts
  # ship — never the test suite, fixtures, or the examples app.
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Benjamin Fox"],
      links: %{
        "GitHub" => @source_url,
        "Mutare" => "https://hexdocs.pm/mutare",
        "Changelog" => "https://hexdocs.pm/mutare_phoenix/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp deps do
    [
      # The host mutation-testing engine. `mutare_phoenix` implements
      # `Mutare.Mutator` / `Mutare.MacroRouting` and rides only its public extension
      # points (`Mutare.Calls`, `Mutare.AST`). Tests use `Mutare.Test` and
      # `Mutare.AST` for AST parse/render, so no direct `:sourceror` dep is needed.
      # A path dep for local development until `mutare` is published; a consuming
      # project depends on both as `:dev`/`:test` deps.
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

  # ExDoc configuration. `mix docs` renders to `doc/` (gitignored). README is the
  # landing page; `Mutare.Phoenix.ConnCall` is `@moduledoc false` plumbing and
  # never appears.
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      # `Mutare.Phoenix.Body`'s moduledoc names core's hidden overlap pass in prose
      # (the reference is worth keeping — it explains the literal-body supersession);
      # don't autolink to it, which also silences the "references hidden" warning.
      skip_code_autolink_to: ["Mutare.Transform.Overlap"],
      groups_for_modules: [
        "Mutator front": [Mutare.Phoenix],
        "Mutator families": [
          Mutare.Phoenix.Plug,
          Mutare.Phoenix.Response,
          Mutare.Phoenix.Redirect,
          Mutare.Phoenix.Session,
          Mutare.Phoenix.Header,
          Mutare.Phoenix.Cookie,
          Mutare.Phoenix.Body
        ]
      ]
    ]
  end

  # `mix check` is the single quality gate: formatting, lint, and type analysis.
  # Any non-zero step aborts the rest, so a green run means all three passed.
  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end
end
