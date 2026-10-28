# Sourced by the hooks and shell scripts: set $PY to a working Python 3.9+.
# Windows often has `python` or `py` but no working `python3` (or only the Store stub,
# which exists but fails), so try each. When python3 itself is not usable, define a
# python3 function, so commands written as `python3 ...` (acceptance lines) still run.
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    PY=python3
elif python -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    PY=python
elif py -3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    PY="py -3"
else
    echo "no Python 3.9+ found (tried python3, python, py -3)" >&2
    exit 1
fi
if [ "$PY" != python3 ]; then
    python3() { $PY "$@"; }
fi
export PYTHONUTF8=1
