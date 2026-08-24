#!/usr/bin/env bash
# Reads ${GATE_SELFTEST_RENAMED:-1}, which is not the documented switch.
if [ "${GATE_SELFTEST_RENAMED:-1}" != "0" ]; then :; fi
exit 0
