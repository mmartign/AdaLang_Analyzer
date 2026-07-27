#!/bin/sh
set -eu

alr exec -- gprbuild -q -P tests/proof_obligations_model.gpr
./bin/proof_obligations_model_test

