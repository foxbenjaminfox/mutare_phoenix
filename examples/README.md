# Examples

A **standalone mini-project** used as a target for Mutare, demonstrating the
`mutare_phoenix` families composed with the base `mutare_plug` ones. Run it from the repo
root (compile the package first so both packages' mutators are on the code path):

```
mix compile
mix mutare examples/demo
```

| Example | Surface | What it demonstrates |
| --- | --- | --- |
| [`demo`](demo/) | Plug + controller | A forgotten `halt` (`:plug_halt`) and an unasserted status (`:http_status`) — both `mutare_plug` families — and an unasserted redirect status (`:redirect_status`, this package): survivors in all three, plus the kills that prove the families catch what *is* asserted. |

The project has **partial test coverage on purpose**: each run surfaces real survivors, and
the `README.md` walks through the test-quality gap behind each one. The recurring lesson is
the packages' thesis — when a function's behaviour *is* its conn transformation, a test that
asserts "something happened" but not *which* transformation leaves a gap Mutare will find.
