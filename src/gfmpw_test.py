import cocotb
import struct
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

def popcount(x):
    return bin(x).count("1")

def neuron(x, w, last_u, shift = 0, threshold = 5):
    # print(x, w, x&w, x & ~w)
    psp = popcount(x & w) - popcount(x & ~w)
    # print("popcount", u, last_u)
    decayed_u = last_u 
    if shift > 0:
        decayed_u -= decayed_u >> shift
    u = psp + decayed_u
    spike = (u >= threshold)
    if spike:
        u -= threshold
    return spike, u

### TESTS #####################################################################
CONTROL_PINS  = 6
DATA_PINS     = 11

RESET         = 0
N_RESET       = (1<<5)
SETUP_WEIGHTS = (1<<5) | (0b001_00 << CONTROL_PINS)
SETUP_INPUT   = (1<<5) | (0b000_00 << CONTROL_PINS)
IDLE          = (1<<5) | (0b010_00 << CONTROL_PINS)
EXECUTE       = (1<<5) | (1 << CONTROL_PINS)


# @cocotb.test()
# async def test_neuron_spike_train(dut):
#     await reset(dut)
#     x=0b1011_1011
#     # x=1
#     # x=0
#     w=0b1111_1111

#     lif = []
#     pwm = []

#     dut._log.info("load weights 1111_1101")
#     dut.uio_in.value = 1
#     dut.ui_in.value = w
#     await ClockCycles(dut.clk, 1)
#     print_chip_state(dut)

#     dut._log.info("input 0000_0001")
#     dut.uio_in.value = 0
#     dut.ui_in.value = x
#     await ClockCycles(dut.clk, 1)

#     dut.uio_in.value = 2

#     for i in range(64):
#         await ClockCycles(dut.clk, 1)
#         lif.append(dut.uo_out[0].value)
#         pwm.append(dut.uo_out[1].value)

#     print(lif, sum(lif))
#     print(pwm, sum(pwm))

#     xs=[]
#     bits = 5
#     alpha = 1.0/(bits**2)
#     x = 0
#     for v in pwm:
#         x = alpha*v + (1-alpha)*x
#         xs.append((2**bits)*x)
#     print((2**bits)*x, sum(xs)/len(xs), "  ---   ", xs)

@cocotb.test()
async def test_snn_silence(dut):
    await reset(dut)
    await ClockCycles(dut.clk, 8)
    dut._log.info("execute")
    dut.io_in.value = EXECUTE
    for i in range(32):
        await ClockCycles(dut.clk, 1)
        print_chip_state(dut)
    await done(dut)

@cocotb.test()
async def test_snn_simple(dut):

    # x = 0b0000_0000_0000_1111
    x = 0b0000_0000_0000_0001

    await reset(dut)
    u = 0
    spike_train = []

    dut.io_in.value = SETUP_WEIGHTS | (0xAA << DATA_PINS)
    for n in range(32):
        await ClockCycles(dut.clk, 1)
        dut.io_in.value = SETUP_WEIGHTS | (1 << DATA_PINS)
    for n in range(32):
        await ClockCycles(dut.clk, 1)
        dut.io_in.value = SETUP_WEIGHTS | (63 << DATA_PINS)
    for n in range(16):
        await ClockCycles(dut.clk, 1)
        dut.io_in.value = SETUP_WEIGHTS | (31 << DATA_PINS)
    await ClockCycles(dut.clk, 1)
    dut.io_in.value = IDLE | (0xAA << DATA_PINS)
    await ClockCycles(dut.clk, 1)
    print_chip_state(dut, print_weights=True)
    await ClockCycles(dut.clk, 1)
    print_chip_state(dut, print_weights=True)

    dut._log.info(f"set input {bin(x)}")
    for v in struct.Struct('<H').pack(x):
        dut.io_in.value = SETUP_INPUT | (v << DATA_PINS)
        await ClockCycles(dut.clk, 1)
    print_chip_state(dut)

    dut.io_in.value = IDLE | (0xAA << DATA_PINS)
    print_chip_state(dut, print_inputs=True)
    await ClockCycles(dut.clk, 1)
    print_chip_state(dut, print_inputs=True)

    dut._log.info("execute")
    dut.io_in.value = EXECUTE
    for i in range(32):
        await ClockCycles(dut.clk, 1)
        print_chip_state(dut)

    await done(dut)

### UTILS #####################################################################

def print_chip_state(dut, sim=None, print_inputs=False, print_weights=False):
    return 
    try:
        internal = dut.tt_um_rejunity_snn_uut
        print(  "W" if dut.uio_in.value & 1 else "I",
                "X" if dut.uio_in.value & 2 else " ",
                dut.ui_in.value, '|',
                internal.inputs.value, '*',
                sum(internal.weights.value),
                internal.inputs.value if print_inputs else "",
                internal.weights.value if print_weights else "", '|',
                (internal.weights_0.value, internal.weights_1.value, internal.weights_2.value) if print_weights else "", '=',
                internal.outputs_0.value,
                internal.outputs_1.value,
                dut.uo_out.value
                # int(internal.neuron.), '|',
                # "$" if internal.neuron.is_spike == 1 else " ",
                # f" vs {sim[1]}" if (sim != None) else "",
                )
    except:
       print(dut.ui_in.value, dut.uio_in.value, ">", dut.uo_out.value)

async def reset(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut.io_in.value = 0
    dut.io_in.value = 0

    # reset
    dut._log.info("reset {shift=0, threshold=5, membrane=0}")
    dut.io_in.value = RESET
    await ClockCycles(dut.clk, 10)
    dut.io_in.value = N_RESET

async def done(dut):
    dut._log.info("DONE!")

def get_output(dut):
    return int(dut.io_out.value)
