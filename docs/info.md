# RFM-1A Lite V2

RFM (Reality Frame Memory) is a hardware state snapshot experiment. This
prototype stores eight 32-bit working-state words and provides two branches
with two saved frames per branch (128 bytes of snapshot storage).

## How it works

`ui_in` carries data. While the host asserts `uio_in[7]`, `uio_in[6:4]`
selects an operation and `uio_in[1:0]` selects a byte. The request is accepted
on its rising edge and must be released before another request. The `uio` pins
remain input-only; all responses appear on `uo_out`.

Operations are: `0` set word address (`ui_in[2:0]`), `1` write byte, `2` read
byte, `3` execute a core command, `4` latch status into `uo_out`, and `5` latch
the four-bit error code into `uo_out[3:0]`. Status is
`{frame_count[1:0],active_branch,error,busy,done,cmd_ready,write_ready}`.

Core commands in `ui_in` are opcode `[2:0]`, branch `[3]`, and frame `[4]`.
Opcodes are NOP=0, COMMIT=1, FORK=2, ROLLBACK=3, and CLEAR=4.

## How to test

Reset the design by holding `rst_n` low for at least two clock cycles, then
release reset and keep `ena` high. Use bus operation 0 to select a word, bus
operation 1 four times to write its four bytes, and bus operation 2 four times
to read them back. Execute COMMIT, modify the working state, and execute
ROLLBACK; the original committed bytes must be restored. The included directed
testbench also checks FORK and independent branch restoration.

For writes and commands, wait until `ready` is high. For COMMIT, FORK,
ROLLBACK, or CLEAR, wait for `busy` to return low before the next operation.

## External hardware

No external hardware is required beyond a Tiny Tapeout demo board or another
controller capable of driving the digital input pins.

