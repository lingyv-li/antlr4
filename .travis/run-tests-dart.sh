#!/bin/bash

set -euo pipefail

mvn -DskipTests install
mvn -q -Dparallel=methods -DthreadCount=4 -Dtest=dart.* test
