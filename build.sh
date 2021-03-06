#!/bin/bash

# Fast fail the script on failures.
set -e

cd shared
pub get
pub run test

cd ../web_client
pub get
pub build

cd ../server
pub get
pub run test
dart --snapshot=server.snapshot bin/server.dart

