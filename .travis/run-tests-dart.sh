#!/bin/bash

set -euo pipefail
ls /home/travis/build/lingyv-li/antlr4/runtime-testsuite/target/classes
ls /home/travis/build/lingyv-li/antlr4/runtime-testsuite/target/classes/Dart
ls /home/travis/build/lingyv-li/antlr4/runtime-testsuite/target/classes/Dart/lib
ls /home/travis/build/lingyv-li/antlr4/runtime-testsuite/target/classes/Dart/lib/src
ls /home/travis/build/lingyv-li/antlr4/runtime-testsuite/target/classes/Dart/lib/src/atn
mvn -q -Dparallel=classes -DthreadCount=4 -Dtest=dart.* test
