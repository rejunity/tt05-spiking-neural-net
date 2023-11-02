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
async def test_snn(dut):

    w = -1
    x = 0b0101_0101_0101_0101
    x = 0b0000_0001

    await reset(dut)
    u = 0
    spike_train = []

    if w >= 0:
        dut._log.info(f"load weights {bin(w)}")
        dut.uio_in.value = 1
        for v in struct.Struct('>I').pack(w):
            dut.ui_in.value = v
            await ClockCycles(dut.clk, 1)
        print_chip_state(dut)

    dut._log.info(f"set input {bin(x)}")
    dut.uio_in.value = 0
    for v in struct.Struct('>I').pack(x):
        dut.ui_in.value = v
        await ClockCycles(dut.clk, 1)
    print_chip_state(dut)

    dut._log.info("execute")
    dut.uio_in.value = 2
    for i in range(16):
        await ClockCycles(dut.clk, 1)
        print_chip_state(dut)

        # spike, u = neuron(x, w, last_u=u)
        # print_chip_state(dut, sim=(spike, u))
        # assert dut.uo_out[0] == spike
        # spike_train.append(dut.uo_out[0].value)
        # dut._log.info(f"OK {sum(spike_train)} {str(spike_train).replace(', ', '')}")

    await done(dut)

### UTILS #####################################################################

def print_chip_state(dut, sim=None):
    try:
        internal = dut.tt_um_rejunity_snn_uut
        print(  "W" if dut.uio_in.value & 1 else "I",
                "X" if dut.uio_in.value & 2 else " ",
                dut.ui_in.value, '|',
                internal.inputs.value, '*',
                internal.weights.value, '=',
                internal.outputs_0.value,
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

    dut.ui_in.value  = 0
    dut.uio_in.value = 0

    # reset
    dut._log.info("reset {shift=0, threshold=5, membrane=0}")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

async def done(dut):
    dut._log.info("DONE!")

def get_output(dut):
    return int(dut.uo_out.value)
