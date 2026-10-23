#!/usr/bin/env bash
# Package the DDRC source for Lambda deployment
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
rm -f build/ddrc-lambda.zip

# zip src/ excluding caches; python3 zipfile keeps us dependency-free
python3 - <<'EOF'
import os
import zipfile

with zipfile.ZipFile("build/ddrc-lambda.zip", "w", zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk("src"):
        dirs[:] = [d for d in dirs if d != "__pycache__"]
        for name in files:
            if not name.endswith(".pyc"):
                zf.write(os.path.join(root, name))
print("Packaged: build/ddrc-lambda.zip")
EOF
