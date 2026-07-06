#!/usr/bin/env bash

RESULT=$(./calc)

if [[ -n "$RESULT" ]]; then
	wl-copy "$RESULT"
fi
