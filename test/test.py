# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge


async def request(dut, op, sub=0, data=0):
    await FallingEdge(dut.clk)
    dut.ui_in.value = data
    dut.uio_in.value = 0x80 | ((op & 7) << 4) | (sub & 3)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)


async def set_addr(dut, addr):
    await request(dut, 0, data=addr & 7)


async def write_word(dut, addr, value):
    await set_addr(dut, addr)
    for byte_no in range(4):
        await request(dut, 1, byte_no, (value >> (8 * byte_no)) & 0xFF)


async def read_word(dut, addr):
    await set_addr(dut, addr)
    value = 0
    for byte_no in range(4):
        await request(dut, 2, byte_no)
        value |= int(dut.uo_out.value) << (8 * byte_no)
    return value


async def status(dut):
    await request(dut, 4)
    return int(dut.uo_out.value)


async def execute(dut, opcode, branch=0, frame=0):
    payload = (opcode & 7) | ((branch & 1) << 3) | ((frame & 1) << 4)
    await request(dut, 3, data=payload)
    for _ in range(64):
        if ((await status(dut)) & 0x08) == 0:
            return
    raise AssertionError("RFM command did not finish")


@cocotb.test()
async def test_rfm_snapshot_and_branches(dut):
    cocotb.start_soon(Clock(dut.clk, 25, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    await execute(dut, 4)  # CLEAR
    await write_word(dut, 0, 0x11223344)
    await write_word(dut, 1, 0x55667788)
    await execute(dut, 1)  # COMMIT branch A frame 0

    await write_word(dut, 0, 0xAABBCCDD)
    await execute(dut, 2, branch=1)  # FORK branch B frame 0
    await write_word(dut, 1, 0xDEADBEEF)
    await execute(dut, 1)  # COMMIT branch B frame 1

    await execute(dut, 3, branch=0, frame=0)
    assert await read_word(dut, 0) == 0x11223344
    assert await read_word(dut, 1) == 0x55667788

    await execute(dut, 3, branch=1, frame=1)
    assert await read_word(dut, 0) == 0xAABBCCDD
    assert await read_word(dut, 1) == 0xDEADBEEF
