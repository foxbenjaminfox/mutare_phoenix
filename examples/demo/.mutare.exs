# Mutare configuration for the demo.
#
# In a real project, `mutare_phoenix` (and `mutare_plug`, which it depends on) are
# dependencies, so their mutators are already on the code path and the lines below are
# unnecessary. Here the demo lives *inside* the `mutare_phoenix` repo, where the packages are
# the root project and its dep — which the `mutare` task does not add to the demo's code
# path — so we append the compiled package `ebin`s ourselves (run `mix compile` in the repo
# root first).
for pkg <- ["mutare_plug", "mutare_phoenix"],
    ebin <- Path.wildcard(Path.expand("_build/*/lib/#{pkg}/ebin")),
    do: Code.append_path(String.to_charlist(ebin))

# Scope mutation to `lib/demo` (the app code), leaving the tiny `Plug.Conn` /
# `Phoenix.Controller` stand-in at `lib/phoenix_surface.ex` unmutated, and enable only the
# two packages' families so every survivor is a conn-transform gap. A real project would
# keep Mutare's built-ins on too, by adding the `:builtins` family:
#
#     [
#       mutators: [:builtins] ++ Mutare.Plug.all() ++ Mutare.Phoenix.all(),
#       extensions: [Mutare.Phoenix]
#     ]
[
  paths: ["lib/demo"],
  mutators: Mutare.Plug.all() ++ Mutare.Phoenix.all(),
  extensions: [Mutare.Phoenix]
]
