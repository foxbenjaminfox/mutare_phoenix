defmodule Mutare.Phoenix.DownloadTest do
  @moduledoc """
  `:download_disposition` — flips the explicit `disposition:` option of
  `Phoenix.Controller.send_download/3` between `:attachment` and `:inline`. Pipe-aware,
  direct/aliased/imported-call aware, and scoped to literal keyword options.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Phoenix.Download

  defp download_diffs(source), do: diffs_for(source, [Download], :download_disposition)

  defp controller(body),
    do: "defmodule MyController do\n  import Phoenix.Controller\n\n#{body}\nend\n"

  describe "the disposition flip" do
    test "qualified send_download/3 flips :attachment to :inline" do
      source = """
      defmodule C do
        def export(conn), do: Phoenix.Controller.send_download(conn, {:file, "/tmp/r.csv"}, disposition: :attachment)
      end
      """

      assert download_diffs(source) == [
               {
                 "Phoenix.Controller.send_download(conn, {:file, \"/tmp/r.csv\"}, disposition: :attachment)",
                 "Phoenix.Controller.send_download(conn, {:file, \"/tmp/r.csv\"}, disposition: :inline)"
               }
             ]
    end

    test "flips :inline to :attachment, keeping the other options" do
      # Short names on purpose: the mutated call is re-rendered by Sourceror, so a source
      # line past the 98-column limit would wrap and obscure the one-atom diff.
      source = """
      defmodule C do
        def export(c, csv), do: Phoenix.Controller.send_download(c, {:binary, csv}, filename: "r", disposition: :inline)
      end
      """

      assert download_diffs(source) == [
               {
                 "Phoenix.Controller.send_download(c, {:binary, csv}, filename: \"r\", disposition: :inline)",
                 "Phoenix.Controller.send_download(c, {:binary, csv}, filename: \"r\", disposition: :attachment)"
               }
             ]
    end

    test "bare imported and aliased calls are recognised" do
      imported =
        controller(
          "  def export(conn, p), do: send_download(conn, {:file, p}, disposition: :attachment)"
        )

      aliased = """
      defmodule C do
        alias Phoenix.Controller, as: PC
        def export(conn, p), do: PC.send_download(conn, {:file, p}, disposition: :inline)
      end
      """

      assert download_diffs(imported) == [
               {"send_download(conn, {:file, p}, disposition: :attachment)",
                "send_download(conn, {:file, p}, disposition: :inline)"}
             ]

      assert download_diffs(aliased) == [
               {"PC.send_download(conn, {:file, p}, disposition: :inline)",
                "PC.send_download(conn, {:file, p}, disposition: :attachment)"}
             ]
    end
  end

  describe "pipe awareness and options shape" do
    test "a piped send_download finds the options at visible index 1" do
      source =
        controller(
          "  def export(conn, csv), do: conn |> send_download({:binary, csv}, filename: \"r.csv\", disposition: :inline)"
        )

      assert download_diffs(source) == [
               {"send_download({:binary, csv}, filename: \"r.csv\", disposition: :inline)",
                "send_download({:binary, csv}, filename: \"r.csv\", disposition: :attachment)"}
             ]
    end

    test "an explicit bracketed options list is recognised" do
      source = """
      defmodule C do
        def export(conn, p), do: Phoenix.Controller.send_download(conn, {:file, p}, [disposition: :inline])
      end
      """

      assert download_diffs(source) == [
               {"Phoenix.Controller.send_download(conn, {:file, p}, disposition: :inline)",
                "Phoenix.Controller.send_download(conn, {:file, p}, disposition: :attachment)"}
             ]
    end
  end

  describe "scope" do
    test "the implicit default, a variable, and an unrecognised atom are left alone" do
      implicit = """
      defmodule C do
        def export(conn, p), do: Phoenix.Controller.send_download(conn, {:file, p}, filename: "r.csv")
      end
      """

      variable = """
      defmodule C do
        def export(conn, p, mode), do: Phoenix.Controller.send_download(conn, {:file, p}, disposition: mode)
      end
      """

      unrecognised = """
      defmodule C do
        def export(conn, p), do: Phoenix.Controller.send_download(conn, {:file, p}, disposition: :download)
      end
      """

      assert download_diffs(implicit) == []
      assert download_diffs(variable) == []
      assert download_diffs(unrecognised) == []
    end

    test "send_download/2 and other Phoenix.Controller calls are untouched" do
      no_opts = """
      defmodule C do
        def export(conn, p), do: Phoenix.Controller.send_download(conn, {:file, p})
      end
      """

      json = "defmodule C do\n  def show(conn), do: Phoenix.Controller.json(conn, %{})\nend\n"

      assert download_diffs(no_opts) == []
      assert download_diffs(json) == []
    end
  end

  describe "superseding the crashing atom leaf (Overlap)" do
    test "with :atom also enabled, no disposition: :mutare leaf remains" do
      source = """
      defmodule C do
        def export(conn, p), do: Phoenix.Controller.send_download(conn, {:file, p}, disposition: :attachment)
      end
      """

      pairs = diffs_for(source, [Download, :atom], :download_disposition)
      atom_pairs = diffs_for(source, [Download, :atom], :atom)

      assert [{_original, mutated}] = pairs
      assert mutated =~ "disposition: :inline"

      refute Enum.any?(atom_pairs, fn {_original, mutated} ->
               String.contains?(mutated, "disposition: :mutare")
             end)
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified send_download flips the disposition option" do
      assert node_mutations(
               "Phoenix.Controller.send_download(conn, {:file, path}, disposition: :attachment)",
               Download
             ) == [
               "Phoenix.Controller.send_download(conn, {:file, path}, disposition: :inline)"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule DownloadCompileDemo do
      import Phoenix.Controller

      def report(conn, path), do: send_download(conn, {:file, path}, disposition: :attachment)

      def export(conn, csv) do
        conn
        |> send_download({:binary, csv}, filename: "r.csv", disposition: :inline)
      end
    end
    """

    assert_metamutant_compiles(source, [Download])
  end
end
