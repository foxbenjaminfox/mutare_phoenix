defmodule Demo.MixProject do
  use Mix.Project

  # A standalone, dependency-free demo project. Run Mutare against it from the
  # mutare_phoenix repo root (the `mutare` mix task comes from the dependency):
  #
  #     mix mutare examples/demo
  #
  # It models a thin Phoenix request surface — an auth plug and a few controller
  # actions — over a tiny stand-in for `Plug.Conn` / `Phoenix.Controller` (so the
  # demo needs no real Phoenix). The custom mutators match on module *name*, so the
  # mutations are exactly what they would be against a real app.
  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.18"
    ]
  end

  def application, do: []
end
