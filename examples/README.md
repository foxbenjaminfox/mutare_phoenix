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
| [`demo`](demo/) | Plug, controllers, channels, PubSub, tokens | Survivors in all seven Phoenix families plus Plug halt and status, alongside kills where the relevant behaviour is asserted. The walkthrough explains the missing assertions for replies, message delivery, token round-trips, payloads, and expiry. |

The project has **partial test coverage on purpose**, following the same pattern as the
Mutare, Plug, LiveView, and Ecto examples: a passing suite with deliberate gaps, and a
walkthrough of the survivors. This demo kills 7 of 25 mutants and leaves 18 survivors.
The [walkthrough](demo/README.md) connects each survivor to its missing assertion.
