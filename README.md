# Tiny Tapeout wrapper for RFM-1A Lite V2

This directory follows the Tiny Tapeout SKY130 Verilog template layout.
The original V2 behavior is exposed through a byte-wide shared-pin protocol.

Local RTL test with Icarus Verilog:

```sh
iverilog -g2012 -o test/tt_rfm_sim.vvp \
  src/rfm1a_lite_core.v src/tt_um_rfm1a_lite.v \
  test/tb_tt_um_rfm1a_lite.sv
vvp test/tt_rfm_sim.vvp
```

Before submission, rename `tt_um_rfm1a_lite` using the GitHub username,
update `info.yaml`, and run the official Tiny Tapeout GitHub Actions flow.
