# cajeta-cloud-local

A filesystem object store for [`dev.cajeta.cloud`](https://github.com/jklappenbach/cajeta-cloud)'s
object-store port, written in Cajeta: every key a file under one root
directory, for development and tests with no account and no network.

```cajeta
import dev.cajeta.cloud.local.FilesystemObjectStore;

FilesystemObjectStore store = heap FilesystemObjectStore("/var/tmp/my-app-store");
String etag #= store.put("reports/2026/q3.pdf", bytes, "application/pdf");
```

**Dev-grade.** Conditional writes (`putIfAbsent`, `putIfMatch`) hold a lock
inside the process, so they are correct for one process only. The capability
document declares `object.dev-grade`, so a deployment that requires a stronger
grade fails at startup instead of losing a race in production.

On disk, `<root>/objects` holds one file a key, one directory a `/` segment;
segments are percent-encoded (only `a-z`, `0-9`, `-`, `_` stay as written) so
any key is a legal name on Linux, macOS and Windows and keys differing only in
case stay distinct. Each file carries its content type, etag and modified time
in a short header before the bytes, and is installed by one temp-and-rename,
so an interrupted put leaves the previous object whole. A key with a `.` or
`..` segment is refused.

**Status: in development (0.1.0 unreleased).** The plan is
`cajeta-cloud-adapters` in the cajeta repository's `agents/`.

## Build and test

```sh
./run-tests.sh
```

The suite runs cajeta-cloud's object-store conformance suite against a temp
root, plus reopen, interrupted-put, listing-parity and key-refusal tests.

## License

Apache-2.0.
