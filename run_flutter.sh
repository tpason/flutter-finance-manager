#!/bin/bash
# Script để chạy Flutter với system Java thay vì snap Java

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

echo "Using Java: $JAVA_HOME"
java -version

flutter "$@"

