defmodule Demo.MixProject do
  use Mix.Project

  # A standalone, dependency-free demo project. Run Mutare against it from the
  # mutare_phoenix repo root (the `mutare` mix task comes from the dependency, and
  # the `Plug.Conn` families from `mutare_plug`, the base package):
  #
  #     mix mutare examples/demo
  #
  # It models an auth plug, controller actions, a room channel, report notifications,
  # and invitation tokens over small framework stand-ins (so the demo needs no real
  # Phoenix). The custom mutators match on module *name* and channel behaviour.
  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.18"
    ]
  end

  def application, do: []
end
