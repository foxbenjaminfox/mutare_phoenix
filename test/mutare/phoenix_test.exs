defmodule Mutare.PhoenixTest do
  @moduledoc """
  The package's preset, its `:extensions` macro routing, and a cross-package integration
  check: a realistic controller + plug surface mutated by the `mutare_plug` and
  `mutare_phoenix` families alongside Mutare's built-ins, recording the expected family
  names and compiling as a single metamutant.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Macro.Spec
  alias Mutare.MacroRouting.Registry
  alias Mutare.Mutator.Dispatch

  doctest Mutare.Phoenix

  # The per-position treatment list a `module_key`/`name`/`arity` call matches in `registry`,
  # or `nil` when unregistered. `Registry.lookup/4` returns the matched `%Entry{}` carrying
  # its `%Spec{}`; `Spec.routing/2` expands its (static `:skip`) treatment over the arity.
  defp routing(registry, module_key, name, arity) do
    case Registry.lookup(registry, module_key, name, arity) do
      nil -> nil
      entry -> Spec.routing(entry.spec, arity)
    end
  end

  describe "all/0" do
    test "is the three families in order" do
      assert Mutare.Phoenix.all() == [
               Mutare.Phoenix.Redirect,
               Mutare.Phoenix.Body,
               Mutare.Phoenix.Download
             ]
    end

    test "every entry resolves as a Mutare.Mutator" do
      for module <- Mutare.Phoenix.all() do
        assert Dispatch.implemented_by?(module)
      end
    end

    test "composes after the built-ins and the mutare_plug families and resolves" do
      # The usage idiom: `[:builtins] ++ Mutare.Plug.all() ++ Mutare.Phoenix.all()`. The
      # `:builtins` token expands to every built-in family in place, then the base package's
      # families, then this package's, in order.
      specs = Mutare.Mutators.resolve([:builtins] ++ Mutare.Plug.all() ++ Mutare.Phoenix.all())
      names = Enum.map(specs, & &1.name)

      assert Enum.take(names, -9) == [
               :plug_halt,
               :http_status,
               :plug_session,
               :resp_header,
               :resp_cookie,
               :resp_body,
               :redirect_status,
               :controller_body,
               :download_disposition
             ]

      # Spot-check the expansion across the built-in categories: an operator family,
      # and two of the per-kind value-literal families.
      assert :arithmetic in names
      assert :integer in names and :atom in names
    end

    test "the front module is an extension, not a mutator" do
      # `:extensions` rejects mutator modules (so a producer can't be enabled by accident as
      # routing-only), so the routing home must never grow a `name/0` + producer.
      refute Dispatch.implemented_by?(Mutare.Phoenix)
      assert Mutare.Extension.validate!([Mutare.Phoenix])
    end
  end

  describe "macro_routes/0 — the defensive Phoenix macro :skip (the :extensions entry)" do
    test "registers the router DSL so core leaves route definitions raw" do
      registry = Registry.build([], [], [Mutare.Phoenix])

      assert routing(registry, [:Phoenix, :Router], :get, 3) == [
               :skip,
               :skip,
               :skip
             ]

      assert routing(registry, [:Phoenix, :Router], :scope, 2) == [:skip, :skip]

      assert routing(registry, [:Phoenix, :Router], :resources, 4) ==
               [:skip, :skip, :skip, :skip]

      # An unregistered name is unaffected.
      assert routing(registry, [:Phoenix, :Router], :unknown, 1) == nil
    end

    test "registers Phoenix.Component.sigil_H/2 so HEEx sigil arguments stay literal" do
      registry = Registry.build([], [], [Mutare.Phoenix])

      assert routing(registry, [:Phoenix, :Component], :sigil_H, 2) == [:skip, :skip]
    end

    test "a ~H return expression does not generate an imported-macro witness" do
      source =
        [
          "defmodule C do",
          "  import Phoenix.Component",
          "",
          "  def render(assigns), do: ~H\"\"\"",
          "  <p>{@name}</p>",
          "  \"\"\"",
          "end"
        ]
        |> Enum.join("\n")

      metamutant = metamutant_source(source, [:builtins], extensions: [Mutare.Phoenix])

      refute metamutant =~ "fn mutare_import_arg1, mutare_import_arg2 ->"
      refute metamutant =~ "sigil_H(mutare_import_arg1, mutare_import_arg2)"

      return_pairs =
        diffs_for(source, [:builtins], :return_value, extensions: [Mutare.Phoenix])

      assert Enum.map(return_pairs, &elem(&1, 1)) == ["nil", ":mutare"]

      assert Enum.all?(return_pairs, fn {original, _mutated} ->
               String.starts_with?(original, "~H")
             end)

      assert_metamutant_compiles(source, [:builtins], extensions: [Mutare.Phoenix])
    end

    test "every registered route skips the matched macro arguments" do
      for {module, name, arity, :skip} <- Mutare.Phoenix.macro_routes() do
        assert module in [Phoenix.Router, Phoenix.Component]
        assert is_atom(name)
        assert arity == :any or (is_integer(arity) and arity >= 0)
      end
    end
  end

  describe "integration across packages" do
    @controller """
    defmodule DemoWeb.PageController do
      import Plug.Conn
      import Phoenix.Controller

      def show(conn, _params) do
        conn
        |> put_status(:ok)
        |> json(%{ok: true})
      end

      def login(conn, _params) do
        redirect(conn, to: "/login", status: :found)
      end

      def block(conn, _params) do
        conn
        |> put_status(:unauthorized)
        |> put_session(:blocked, true)
        |> put_resp_header("x-blocked", "true")
        |> put_resp_cookie("blocked", "true", same_site: "Strict")
        |> halt()
      end

      def health(conn, _params) do
        send_resp(conn, 200, "ok")
      end

      def ping(conn, _params) do
        text(conn, "pong")
      end

      def export(conn, _params) do
        send_download(conn, {:binary, "a,b"}, filename: "r.csv", disposition: :attachment)
      end
    end
    """

    test "each family fires on the conn transforms it owns" do
      names =
        @controller
        |> diffs(Mutare.Plug.all() ++ Mutare.Phoenix.all())
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.sort()

      assert names == [
               :controller_body,
               :download_disposition,
               :http_status,
               :plug_halt,
               :plug_session,
               :redirect_status,
               :resp_body,
               :resp_cookie,
               :resp_header
             ]
    end

    test "the whole surface compiles as one metamutant, built-ins included" do
      mutators = Mutare.Mutators.all() ++ Mutare.Plug.all() ++ Mutare.Phoenix.all()
      assert_metamutant_compiles(@controller, mutators, extensions: [Mutare.Phoenix])
    end
  end
end
