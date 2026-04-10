#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import sys


PATCHES = [
    (
        b"/usr/lib/x86_64-linux-gnu/wpe-webkit-2.0/injected-bundle/",
        b"./lib/wpe-webkit-2.0/injected-bundle/",
    ),
    (
        b"/usr/lib/x86_64-linux-gnu/wpe-webkit-1.1/injected-bundle/",
        b"./lib/wpe-webkit-1.1/injected-bundle/",
    ),
    (
        b"/usr/lib/x86_64-linux-gnu/wpe-webkit-1.0/injected-bundle/",
        b"./lib/wpe-webkit-1.0/injected-bundle/",
    ),
    (b"/usr/lib/x86_64-linux-gnu/wpe-webkit-2.0", b"./lib/wpe-webkit-2.0"),
    (b"/usr/lib/x86_64-linux-gnu/wpe-webkit-1.1", b"./lib/wpe-webkit-1.1"),
    (b"/usr/lib/x86_64-linux-gnu/wpe-webkit-1.0", b"./lib/wpe-webkit-1.0"),
    (b"/usr/share/wpe-webkit-2.0", b"./share/wpe-webkit-2.0"),
    (b"/usr/share/wpe-webkit-1.1", b"./share/wpe-webkit-1.1"),
    (b"/usr/share/wpe-webkit-1.0", b"./share/wpe-webkit-1.0"),
]


def _padded_replacement(old: bytes, new: bytes) -> bytes:
    if len(new) > len(old):
        raise ValueError(f"Replacement {new!r} is longer than {old!r}")
    return new + (b"\0" * (len(old) - len(new)))


def patch_file(path: pathlib.Path) -> bool:
    data = path.read_bytes()
    original = data
    for old, new in PATCHES:
        replacement = _padded_replacement(old, new)
        data = data.replace(old, replacement)
    if data == original:
        return False
    path.write_bytes(data)
    return True


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: patch_linux_wpe_runtime_paths.py <file> [<file> ...]", file=sys.stderr)
        return 1

    patched_any = False
    for raw_path in argv[1:]:
        path = pathlib.Path(raw_path)
        if patch_file(path):
            patched_any = True

    return 0 if patched_any or len(argv) > 1 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
