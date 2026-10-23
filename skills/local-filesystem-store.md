---
id: local-filesystem-store
applies-to: [dev/cajeta/cloud/local/FilesystemObjectStore]
title: A filesystem object store for development — FilesystemObjectStore
description: Use dev.cajeta.cloud.local.FilesystemObjectStore as the object-store port in development and tests, and know its dev-grade limits, on-disk layout and key rules.
---

# FilesystemObjectStore

`dev.cajeta.cloud.local.FilesystemObjectStore` implements cajeta-cloud's
`ObjectStore` over a directory. Code written against the port runs unchanged
against it, the memory driver, or S3.

```cajeta
FilesystemObjectStore store = heap FilesystemObjectStore(rootDir);
String etag #= store.put("a/b.txt", bytes, "text/plain");
CondResult r #= store.putIfMatch("a/b.txt", next, "text/plain", etag);
```

## When to use it

- Development and tests that should survive a restart (unlike the memory
  driver) without an account or network.
- **Not** for several processes sharing a root: conditional writes take an
  in-process lock (`object.dev-grade`). Production startup should
  `capabilities().assertAll(...)` a grade this driver does not declare.

## Behaviour

- Each object is one file `<root>/objects/<seg>=d/.../<last>=o`, segments
  percent-encoded (only `a-z 0-9 - _` raw), so any key is a legal file name
  and `Readme`/`readme` stay distinct even on case-insensitive filesystems.
- Metadata (content type, etag, modified ms) is a header in the same file; a
  put is one temp-and-rename, so an interrupted put leaves the old object.
- A key that is empty or has a `.` or `..` segment throws `PROVIDER_ERROR`
  ("refused key").
- Listing pages exactly as the memory driver does; ordering is byte order.
- `openWrite` stages the whole object in memory and `openRead` reads it whole:
  this is a development store, not a large-object store. `getRange` seeks.
- Multipart parts are staged as files under `<root>/uploads/<id>/` and
  assembled at `complete`.
