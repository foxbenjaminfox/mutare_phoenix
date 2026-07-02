# Demo: a Phoenix request surface

A standalone mini-project modelling the **conn-transform surface** of a Phoenix app — an
auth plug and a few controller actions — over a tiny stand-in for `Plug.Conn` /
`Phoenix.Controller` (so it needs no real Phoenix). The custom mutators match calls by
module *name*, so the mutations are exactly what they'd be against a real app.

A plug or action returns a *transformed conn*, so its whole contract is **which
conn-transforming call ran** — the status it set, whether it halted.
These are precisely the calls a suite tends to under-assert, and each gap becomes a
survivor.

From the repo root (compile the package once so its mutators are loadable):

```
mix compile
mix mutare examples/demo
```

It scans 6 mutants across 2 files and reports three survivors — one per gap below — for a
mutation score of 50.0%:

```
lib/demo/auth.ex:17  [plug_halt, in-place]  SURVIVED
-      |> Plug.Conn.halt()
+      |> Elixir.Function.identity()

lib/demo/page_controller.ex:17  [http_status, in-place]  SURVIVED
-    |> Plug.Conn.put_status(:created)
+    |> Plug.Conn.put_status(:ok)

lib/demo/page_controller.ex:17  [http_status, in-place]  SURVIVED
-    |> Plug.Conn.put_status(:created)
+    |> Plug.Conn.put_status(:accepted)

mutation score: 50.0%  (3 killed, 3 survived, 6 total)
```

Each survivor is a real test-quality gap. Grouped by family:

- **`:plug_halt` — the forgotten halt** (`Demo.Auth`). The auth plug sets `401` *and*
  halts. The test asserts the `401` (so the `:http_status` mutant `:unauthorized →
  :forbidden` is **killed**) but never asserts the pipeline *halted*. Drop the `halt` and
  an anonymous request still gets `401` set — yet now falls through to the guarded action.
  The missing `assert conn.halted` is the gap; the classic authorization-bypass mutation.

- **`:http_status` — the unasserted status** (`Demo.PageController.create`). `create`
  answers `201 Created`, but its test checks only the response *body* (`%{id: 1}`), never
  the status. So swapping `:created` for another success (`:ok`, `:accepted`) is invisible.
  Two survivors, one per plausible sibling. (Contrast `index`, which **does** assert
  `:ok` — its `:created`/`:no_content` mutants are killed.)

The lesson is the package's whole thesis: when a function's behaviour *is* its conn
transformation, asserting "something happened" isn't enough — you have to assert *which*
transformation, with *what* arguments. Mutare turns every place you didn't into a survivor.

> Why `:ok → :error` (or `:mutare`) doesn't already cover `:http_status`: in a status
> position both of Mutare's built-in atom swaps **crash** (`:error`/`:mutare` aren't valid
> statuses), an uninformative kill. `:http_status` swaps to a *valid* sibling so a survivor
> means a genuine missing assertion, not a crash — and Mutare's overlap pruning drops the
> redundant crashing leaves.
