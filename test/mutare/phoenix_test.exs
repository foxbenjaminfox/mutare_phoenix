defmodule Mutare.PhoenixTest do
  @moduledoc """
  The package's presets and a cross-family integration check: a realistic controller +
  plug surface mutated by both families alongside Mutare's built-ins, recording the
  expected family names and compiling as a single metamutant.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Mutator.Dispatch

  doctest Mutare.Phoenix

  describe "all/0" do
    test "is the two families in order" do
      assert Mutare.Phoenix.all() == [
               Mutare.Phoenix.Plug,
               Mutare.Phoenix.Response
             ]
    end

    test "every entry resolves as a Mutare.Mutator" do
      for module <- Mutare.Phoenix.all() do
        assert Dispatch.implemented_by?(module)
      end
    end

    test "splices into a :mutators list after the built-ins and resolves" do
      # The usage idiom: `[:builtins] ++ Mutare.Phoenix.all()`. The `:builtins` token
      # expands to every built-in family in place, then this package's two follow, in
      # order.
      specs = Mutare.Mutators.resolve([:builtins] ++ Mutare.Phoenix.all())
      names = Enum.map(specs, & &1.name)

      assert Enum.take(names, -2) == [:plug_halt, :http_status]
      assert :literal in names and :atom in names
    end
  end

  describe "integration across families" do
    @controller """
    defmodule DemoWeb.PageController do
      import Plug.Conn
      import Phoenix.Controller

      def show(conn, _params) do
        conn
        |> put_status(:ok)
        |> json(%{ok: true})
      end

      def block(conn, _params) do
        conn
        |> put_status(:unauthorized)
        |> halt()
      end
    end
    """

    test "each family fires on the conn transforms it owns" do
      names =
        @controller
        |> diffs(Mutare.Phoenix.all())
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.sort()

      assert names == [:http_status, :plug_halt]
    end

    test "the whole surface compiles as one metamutant, built-ins included" do
      mutators = Mutare.Mutators.all() ++ Mutare.Phoenix.all()
      assert_metamutant_compiles(@controller, mutators)
    end
  end
end
