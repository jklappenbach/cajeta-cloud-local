# cajeta-cloud-local

The filesystem object store for dev.cajeta.cloud (package `dev.cajeta.cloud.local`).
Spec and plan: `specs/cajeta-cloud-adapters-spec.md` (§4) and
`agents/cajeta-cloud-adapters-plan.md` (Unit 5) in the cajeta repository; this
repo carries no specs of its own.

## Build & test

```sh
./run-tests.sh      # resolves dependency archives, builds the .cja, runs @Test discovery
KEEP_OUT=1 ./run-tests.sh   # keep the test binary and the test roots
```

## Rules

- Test first: the failing test before the implementation, every change.
- Dev-grade: one process. Do not claim multi-process safety without file locks
  and a test that proves it (spec §4.3).
- Listing must page exactly as cajeta-cloud's MemoryObjectStore does; the
  parity test compares them.
- Releases ship from the `release` branch; CI's guard refuses a tag not on it.
