# Tiny Tapeout wrapper for RFM-1A Lite V2

This repository contains the SKY130 Tiny Tapeout implementation of RFM-1A
Lite. The V2 core exposes eight 32-bit working-state words, two branches, and
two saved frames per branch through a byte-wide Tiny Tapeout pin protocol.

The GitHub Actions flow checks:

- RTL behavior with Cocotb and Icarus Verilog
- Tiny Tapeout documentation and metadata
- SKY130 GDS hardening and precheck
- Gate-level behavior after physical implementation

The configured clock period is 25 ns (40 MHz), matching the verified V2 target.
See `docs/info.md` for the byte-bus protocol and operating instructions.
