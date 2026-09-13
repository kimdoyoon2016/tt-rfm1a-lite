#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$project_root/build"
mkdir -p "$build_dir"

rtl=("$project_root"/rtl/*.sv)
for test_file in "$project_root"/tb/tb_*.sv; do
    top="$(basename "$test_file" .sv)"
    output="$build_dir/$top.vvp"
    iverilog -g2012 -Wall -s "$top" -o "$output" "${rtl[@]}" "$test_file"
    vvp "$output"
done

echo "PASS: all P1 behavioral simulations completed"
