defmodule Mutare.Phoenix.BodyTest do
  @moduledoc """
  `:controller_body` — blanks the data argument of `Phoenix.Controller.json/2` (to `%{}`)
  and of `text/2` / `html/2` (to `""`), pipe-aware, and it supersedes the built-in
  `:string` leaves on a literal text/html body.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.Body

  defp body_diffs(source), do: diffs_for(source, [Body], :controller_body)

  # Wrap a controller body in a module importing `Phoenix.Controller`, the
  # `use ..., :controller` form.
  defp controller(body),
    do: "defmodule MyController do\n  import Phoenix.Controller\n\n#{body}\nend\n"

  describe "blanking across renderers and written forms" do
    test "qualified json/2 blanks a map literal to %{}" do
      source = """
      defmodule C do
        def show(conn, user), do: Phoenix.Controller.json(conn, %{id: user.id})
      end
      """

      assert body_diffs(source) == [
               {"Phoenix.Controller.json(conn, %{id: user.id})",
                "Phoenix.Controller.json(conn, %{})"}
             ]
    end

    test "qualified json/2 blanks a dynamic body" do
      source = """
      defmodule C do
        def show(conn, payload), do: Phoenix.Controller.json(conn, payload)
      end
      """

      assert body_diffs(source) == [
               {"Phoenix.Controller.json(conn, payload)", "Phoenix.Controller.json(conn, %{})"}
             ]
    end

    test "qualified text/2 blanks a literal body" do
      source = """
      defmodule C do
        def ping(conn), do: Phoenix.Controller.text(conn, "pong")
      end
      """

      assert body_diffs(source) == [
               {"Phoenix.Controller.text(conn, \"pong\")", "Phoenix.Controller.text(conn, \"\")"}
             ]
    end

    test "qualified html/2 blanks a call-valued body" do
      source = """
      defmodule C do
        def page(conn, assigns), do: Phoenix.Controller.html(conn, render_page(assigns))
      end
      """

      assert body_diffs(source) == [
               {"Phoenix.Controller.html(conn, render_page(assigns))",
                "Phoenix.Controller.html(conn, \"\")"}
             ]
    end

    test "bare imported json/2 is recognised and stays bare" do
      assert body_diffs(controller("  def show(conn), do: json(conn, %{ok: true})")) ==
               [{"json(conn, %{ok: true})", "json(conn, %{})"}]
    end

    test "aliased C.text/2 is recognised" do
      source = """
      defmodule C do
        alias Phoenix.Controller, as: PC
        def ping(conn), do: PC.text(conn, "pong")
      end
      """

      assert body_diffs(source) == [{"PC.text(conn, \"pong\")", "PC.text(conn, \"\")"}]
    end
  end

  describe "pipe awareness" do
    test "piped text/2 blanks the lone visible argument" do
      source = controller("  def ping(conn), do: conn |> text(\"pong\")")

      assert body_diffs(source) == [{"text(\"pong\")", "text(\"\")"}]
    end

    test "piped json/2 after a status stage finds the body at visible index 0" do
      source =
        controller(
          "  def create(conn), do: conn |> Plug.Conn.put_status(:created) |> json(%{id: 1})"
        )

      assert body_diffs(source) == [{"json(%{id: 1})", "json(%{})"}]
    end
  end

  describe "scope" do
    test "already-blank bodies are left alone — the mutant would change nothing" do
      json = "defmodule C do\n  def show(conn), do: Phoenix.Controller.json(conn, %{})\nend\n"
      text = "defmodule C do\n  def ping(conn), do: Phoenix.Controller.text(conn, \"\")\nend\n"

      assert body_diffs(json) == []
      assert body_diffs(text) == []
    end

    test "wrong arities, render/3, and Plug.Conn bodies are left alone" do
      wrong_arity = "defmodule C do\n  def show(conn), do: Phoenix.Controller.json(conn)\nend\n"

      render = """
      defmodule C do
        def show(conn, user), do: Phoenix.Controller.render(conn, "show.html", user: user)
      end
      """

      plug_body =
        "defmodule C do\n  def show(conn), do: Plug.Conn.send_resp(conn, 200, \"ok\")\nend\n"

      assert body_diffs(wrong_arity) == []
      assert body_diffs(render) == []
      assert body_diffs(plug_body) == []
    end
  end

  describe "superseding the literal body's string leaves (Overlap)" do
    test "with :string also enabled, only the blank rewrite remains on a text body" do
      source = "defmodule C do\n  def ping(c), do: Phoenix.Controller.text(c, \"pong\")\nend\n"
      pairs = diffs_for(source, [Body, :string], :controller_body)
      string_pairs = diffs_for(source, [Body, :string], :string)

      assert pairs == [
               {"Phoenix.Controller.text(c, \"pong\")", "Phoenix.Controller.text(c, \"\")"}
             ]

      # The rewrite covers the body node, so both `:string` leaves there — the sentinel
      # `"mutare"` and the duplicate `""` — are pruned.
      assert string_pairs == []
    end

    test "a bare imported call stays bare in the rewrite, so the pruning still applies" do
      source = controller("  def page(conn), do: html(conn, \"<p>hi</p>\")")
      pairs = diffs_for(source, [Body, :string], :controller_body)
      string_pairs = diffs_for(source, [Body, :string], :string)

      assert pairs == [{"html(conn, \"<p>hi</p>\")", "html(conn, \"\")"}]
      assert string_pairs == []
    end

    test "a json map literal keeps its interior leaf mutants" do
      source =
        "defmodule C do\n  def show(c), do: Phoenix.Controller.json(c, %{name: \"x\"})\nend\n"

      string_pairs = diffs_for(source, [Body, :string], :string)

      # The rewrite covers the whole map node, not its descendants, so the `"x"` literal
      # inside keeps both of its `:string` leaves.
      assert {"\"x\"", "\"\""} in string_pairs
      assert {"\"x\"", "\"mutare\""} in string_pairs
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified json/2 blanks its body argument" do
      assert node_mutations("Phoenix.Controller.json(conn, data)", Body) == [
               "Phoenix.Controller.json(conn, %{})"
             ]
    end

    test "qualified text/2 blanks its body argument" do
      assert node_mutations("Phoenix.Controller.text(conn, \"pong\")", Body) == [
               "Phoenix.Controller.text(conn, \"\")"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule BodyCompileDemo do
      import Phoenix.Controller

      def show(conn, user), do: json(conn, %{id: user.id})
      def ping(conn), do: text(conn, "pong")

      def page(conn, markup) do
        conn
        |> Plug.Conn.put_status(:ok)
        |> html(markup)
      end
    end
    """

    assert_metamutant_compiles(source, [Body])
  end
end
