# Demo: a Phoenix request surface

A standalone mini-project modelling the **conn-transform surface** of a Phoenix app — an
auth plug and a few controller actions — over a tiny stand-in for `Plug.Conn` /
`Phoenix.Controller` (so it needs no real Phoenix). The custom mutators match calls by
module *name*, so the mutations are exactly what they'd be against a real app.

A plug or action returns a *transformed conn*, so its whole contract is **which
conn-transforming call ran** — the status it set, whether it halted.
These are precisely the calls a suite tends to under-assert, and each gap becomes a
survivor.

From the repo root (compile the package once so both packages' mutators are loadable —
`mutare_plug`'s families come in through the dependency):

```
mix compile
mix mutare examples/demo
```

It scans 8 mutants across 2 files and reports five survivors across the three visible gaps
below, for a mutation score of 37.5%:

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

lib/demo/page_controller.ex:23  [redirect_status, in-place]  SURVIVED
-    Phoenix.Controller.redirect(conn, to: "/login", status: :found)
+    Phoenix.Controller.redirect(conn, to: "/login", status: :moved_permanently)

lib/demo/page_controller.ex:23  [redirect_status, in-place]  SURVIVED
-    Phoenix.Controller.redirect(conn, to: "/login", status: :found)
+    Phoenix.Controller.redirect(conn, to: "/login", status: :see_other)

mutation score: 37.5%  (3 killed, 5 survived, 8 total)
```

Each survivor is a real test-quality gap. Grouped by family — the first two are `mutare_plug`
families composed in through `Mutare.Plug.all/0`, the third is this package's:

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

- **`:redirect_status` — the unasserted redirect status** (`Demo.PageController.login`).
  `login` redirects to `"/login"` with an explicit `:found`, but its test checks only the
  target. So changing the status to another valid redirect status (`:moved_permanently`,
  `:see_other`) is invisible. Two survivors, one per plausible sibling.

The lesson is the packages' whole thesis: when a function's behaviour *is* its conn
transformation, asserting "something happened" isn't enough — you have to assert *which*
transformation, with *what* arguments. Mutare turns every place you didn't into a survivor.

> Why `:ok → :error` (or `:mutare`) doesn't already cover `:http_status` /
> `:redirect_status`: in a status
> position both of Mutare's built-in atom swaps **crash** (`:error`/`:mutare` aren't valid
> statuses), an uninformative kill. These families swap to a *valid* sibling so a survivor
> means a genuine missing assertion, not a crash — and Mutare's overlap pruning drops
> redundant crashing leaves.
