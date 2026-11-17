#!/bin/sh
set -eu

/app/bin/tela eval "Tela.Release.migrate()"
/app/bin/tela eval "Tela.Release.seed()"

exec /app/bin/tela start
