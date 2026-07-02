defmodule Mutare.Phoenix.RedirectTest do
  @moduledoc """
  `:redirect_status` — swaps the explicit atom `status:` option of
  `Phoenix.Controller.redirect/2` for a plausible redirect-status sibling. Pipe-aware,
  direct/aliased/imported-call aware, and scoped to literal keyword options.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.Redirect

  defp redirect_diffs(source), do: diffs_for(source, [Redirect], :redirect_status)

  # Wrap a controller body in a module importing `Phoenix.Controller`, the
  # `use ..., :controller` form.
  defp controller(body),
    do: "defmodule MyController do\n  import Phoenix.Controller\n\n#{body}\nend\n"

  describe "the curated redirect-status swap table" do
    test "qualified redirect/2 swaps an explicit :found status" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)\nend\n"

      assert redirect_diffs(source) == [
               {
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)",
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :moved_permanently)"
               },
               {
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)",
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :see_other)"
               }
             ]
    end

    test "permanent redirects can move across permanence and method-preservation axes" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, status: :moved_permanently, to: \"/old\")\nend\n"

      assert redirect_diffs(source) == [
               {
                 "Phoenix.Controller.redirect(conn, status: :moved_permanently, to: \"/old\")",
                 "Phoenix.Controller.redirect(conn, status: :found, to: \"/old\")"
               },
               {
                 "Phoenix.Controller.redirect(conn, status: :moved_permanently, to: \"/old\")",
                 "Phoenix.Controller.redirect(conn, status: :permanent_redirect, to: \"/old\")"
               }
             ]
    end

    test "method-preserving redirects swap with their temporary/permanent sibling" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/moved\", status: :permanent_redirect)\nend\n"

      assert redirect_diffs(source) == [
               {
                 "Phoenix.Controller.redirect(conn, to: \"/moved\", status: :permanent_redirect)",
                 "Phoenix.Controller.redirect(conn, to: \"/moved\", status: :moved_permanently)"
               },
               {
                 "Phoenix.Controller.redirect(conn, to: \"/moved\", status: :permanent_redirect)",
                 "Phoenix.Controller.redirect(conn, to: \"/moved\", status: :temporary_redirect)"
               }
             ]
    end
  end

  describe "written forms" do
    test "an aliased Controller.redirect(...) swaps the status option" do
      source = """
      defmodule C do
        alias Phoenix.Controller, as: Controller
        def show(conn), do: Controller.redirect(conn, to: "/login", status: :see_other)
      end
      """

      assert redirect_diffs(source) == [
               {
                 "Controller.redirect(conn, to: \"/login\", status: :see_other)",
                 "Controller.redirect(conn, to: \"/login\", status: :found)"
               }
             ]
    end

    test "a bare imported redirect(...) swaps the status option" do
      source =
        controller(
          "  def show(conn), do: redirect(conn, to: \"/login\", status: :temporary_redirect)"
        )

      assert redirect_diffs(source) == [
               {
                 "redirect(conn, to: \"/login\", status: :temporary_redirect)",
                 "redirect(conn, to: \"/login\", status: :found)"
               },
               {
                 "redirect(conn, to: \"/login\", status: :temporary_redirect)",
                 "redirect(conn, to: \"/login\", status: :permanent_redirect)"
               }
             ]
    end
  end

  describe "pipe awareness and options shape" do
    test "a piped redirect finds the options as its lone visible argument" do
      source =
        controller("  def show(conn), do: conn |> redirect(to: \"/login\", status: :found)")

      assert redirect_diffs(source) == [
               {
                 "redirect(to: \"/login\", status: :found)",
                 "redirect(to: \"/login\", status: :moved_permanently)"
               },
               {
                 "redirect(to: \"/login\", status: :found)",
                 "redirect(to: \"/login\", status: :see_other)"
               }
             ]
    end

    test "an explicit bracketed options list is recognised" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, [to: \"/login\", status: :found])\nend\n"

      assert redirect_diffs(source) == [
               {
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)",
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :moved_permanently)"
               },
               {
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)",
                 "Phoenix.Controller.redirect(conn, to: \"/login\", status: :see_other)"
               }
             ]
    end
  end

  describe "scope" do
    test "a redirect relying on Phoenix's implicit default status is left alone" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/login\")\nend\n"

      assert redirect_diffs(source) == []
    end

    test "integer, variable, and unrecognised atom statuses are left alone" do
      integer =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/login\", status: 302)\nend\n"

      variable =
        "defmodule C do\n  def show(conn, status), do: Phoenix.Controller.redirect(conn, to: \"/login\", status: status)\nend\n"

      unrecognised =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/login\", status: :not_modified)\nend\n"

      assert redirect_diffs(integer) == []
      assert redirect_diffs(variable) == []
      assert redirect_diffs(unrecognised) == []
    end

    test "non-redirect Phoenix.Controller calls and wrong-arity redirects are untouched" do
      json = "defmodule C do\n  def show(conn), do: Phoenix.Controller.json(conn, %{})\nend\n"

      wrong_arity =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn)\nend\n"

      assert redirect_diffs(json) == []
      assert redirect_diffs(wrong_arity) == []
    end
  end

  describe "superseding the crashing atom leaf (Overlap)" do
    test "with :atom also enabled, no status: :mutare leaf remains" do
      source =
        "defmodule C do\n  def show(conn), do: Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)\nend\n"

      atom_pairs = diffs_for(source, [Redirect, :atom], :atom)

      refute Enum.any?(atom_pairs, fn {_original, mutated} ->
               String.contains?(mutated, "status: :mutare")
             end)
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified redirect swaps the status option" do
      assert node_mutations(
               "Phoenix.Controller.redirect(conn, to: \"/login\", status: :found)",
               Redirect
             ) == [
               "Phoenix.Controller.redirect(conn, to: \"/login\", status: :moved_permanently)",
               "Phoenix.Controller.redirect(conn, to: \"/login\", status: :see_other)"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule RedirectCompileDemo do
      import Phoenix.Controller

      def login(conn), do: redirect(conn, to: "/login", status: :found)

      def moved(conn) do
        conn
        |> redirect(to: "/new", status: :permanent_redirect)
      end
    end
    """

    assert_metamutant_compiles(source, [Redirect])
  end
end
