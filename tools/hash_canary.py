#!/usr/bin/env python3
import sys, hashlib

if len(sys.argv) != 3:
    print("Usage: hash_canary.py <username> <password>", file=sys.stderr)
    sys.exit(1)

u, p = sys.argv[1], sys.argv[2]
h = hashlib.sha256((u + "\0" + p).encode()).hexdigest()
print(h)
