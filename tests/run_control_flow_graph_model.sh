#!/bin/sh
set -eu

alr exec -- gprbuild -q -P tests/control_flow_graph_model.gpr
./bin/control_flow_graph_model_test
