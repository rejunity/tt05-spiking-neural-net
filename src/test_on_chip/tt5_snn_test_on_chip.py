from machine import Pin
from ttboard.mode import RPMode
from ttboard.demoboard import DemoBoard

SETUP_WEIGHTS = 0b001_00
SETUP_INPUT = 0b000_00
IDLE = 0b010_00
EXECUTE = 1

def init_test():
    # get a handle to the board
    tt = DemoBoard()
    tt.input_byte=0
    tt.bidir_byte= 0
    tt.reset_project(True)
    tt.reset_project(False)
    # enable a specific project, e.g.
    tt.shuttle.tt_um_rejunity_snn.enable()
    print(f'Project {tt.shuttle.enabled.name} running ({tt.shuttle.enabled.repo})')
    # start automatic project clocking
    tt.clock_project_PWM(10e3) # clocking projects @ 10MHz
    time.sleep_ms(10)    
    # stop automatic project clocking
    tt.clock_project_stop()
    time.sleep_ms(10)
    tt.bidir_mode=[1,1,1,1,1,0,0,0] #bidir_direction: bits set to 1 are driven by RP2040
    # print all the info
    print(f'Output is now {tt.output_byte:08b}')
    print(f'the bidir modes are now {tt.bidir_mode}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')
    print(f'input is now {tt.input_byte:08b}')


######################################
# Phase 1: Weight Setup
def weight_setup():
    print(f'SETUP_WEIGHTS')
    tt.bidir_byte=SETUP_WEIGHTS    #dut.uio_in.value = SETUP_WEIGHTS ##bidir_byte: actual value to set (only applies to outputs)
    print(f'uio0 is now {tt.uio0.value()}')
    print(f'uio1 is now {tt.uio1.value()}')
    print(f'uio2 is now {tt.uio2.value()}')
    print(f'uio3 is now {tt.uio3.value()}')
    print(f'uio4 is now {tt.uio4.value()}')
    
    tt.input_byte=0xAA   #dut.ui_in.value = 0xAA
    
    for n in range(32):
        #tt.clock_project_once()
        tt.input_byte= 1
        tt.clock_project_once()
        print(f'Output is now {tt.output_byte:08b}')
        print(f'Bidirs is now {tt.bidir_byte:08b}')
        print(f'input is now {tt.input_byte:08b}')
    
    for n in range(32):
        #tt.clock_project_once()
        tt.input_byte= 63
        tt.clock_project_once()
        print(f'Output is now {tt.output_byte:08b}')
        print(f'Bidirs is now {tt.bidir_byte:08b}')
        print(f'input is now {tt.input_byte:08b}')
    
    for n in range(16):
        #tt.clock_project_once()
        tt.input_byte= 31
        tt.clock_project_once()
        print(f'Output is now {tt.output_byte:08b}')
        print(f'Bidirs is now {tt.bidir_byte:08b}')
        print(f'input is now {tt.input_byte:08b}')
    # for n in range(32):
        # #tt.clock_project_once()
        # tt.input_byte = min(255, 7+n*3)
        # tt.clock_project_once()
    # for n in range(32):
        # #tt.clock_project_once()
        # tt.input_byte = min(255, 15+n*11)
        # tt.clock_project_once()
    # for n in range(16):
        # #tt.clock_project_once()
        # tt.input_byte = min(255, 63+n*21)
        # tt.clock_project_once()
    #tt.clock_project_once()
    tt.bidir_byte = IDLE
    tt.input_byte = 0xAA
    tt.clock_project_once()
    print(f'Output is now {tt.output_byte:08b}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')
    print(f'input is now {tt.input_byte:08b}')
    tt.clock_project_once()
    print(f'Output is now {tt.output_byte:08b}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')
    print(f'input is now {tt.input_byte:08b}')

def input_setup(input_byte_0,input_byte_1):
    ######################################
    # Phase 2: Input Setup
    print(f'SETUP_INPUT')
    tt.bidir_byte = SETUP_INPUT
    tt.input_byte= input_byte_0
    time.sleep_ms(1)
    tt.clock_project_once()
    tt.input_byte= input_byte_1
    tt.clock_project_once()
    print(f'Output is now {tt.output_byte:08b}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')
    print(f'input is now {tt.input_byte:08b}')

def idle_func():
    ######################################
    # Phase 3: IDLE
    tt.bidir_byte= IDLE
    tt.input_byte=0xAA
    print(f'input is now {tt.input_byte:08b}')
    print(f'Output is now {tt.output_byte:08b}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')
    tt.clock_project_once()
    print(f'input is now {tt.input_byte:08b}')
    print(f'Output is now {tt.output_byte:08b}')
    print(f'Bidirs is now {tt.bidir_byte:08b}')

def execute_func():
    ######################################
    # Phase 4: Execute
    print(f'EXECUTE')
    tt.bidir_byte = EXECUTE
    for i in range(32):
        tt.clock_project_once()
        print(f'input is now {tt.input_byte:08b}')
        print(f'Output is now {tt.output_byte:08b}')
        print(f'Bidirs is now {tt.bidir_byte:08b}')

def apply_spikes(input_bytes,sleep_ms):
    for i in range(int(len(input_bytes)/2)):
        input_setup(input_bytes[i],input_bytes[i+1])
        idle_func()
        execute_func()
        time.sleep_ms(sleep_ms)
        print(f'input is now {tt.input_byte:08b}')
        print(f'Output is now {tt.output_byte:08b}')
        print(f'Bidirs is now {tt.bidir_byte:08b}')
        print(f'Repetition nummber: {i+1}')


init_test()
tt.clock_project_stop()
# weight_setup() # with default weights
input_byte_0= 0x01
input_byte_1=0x05
input_setup(input_byte_0,input_byte_1)
idle_func()
execute_func()
idle_func()
time.sleep_ms(10)

#########################################################
# Test with different inputs
input_bytes=[0x01,0x05,0x01,0x0A,0x01,0x03,0x01,0x01,
            0x01,0x00,0x01,0x0F,0x09,0x05,0x01,0xFF]

idle_func()
weight_setup()
for i in range(10):
    apply_spikes(input_bytes,10)

#######################################
# # threshold Setup
# def thresholds_setup_func():
    # print(f'thresholds_setup')
    # tt.bidir_byte=thresholds_setup    
    # print(f'uio0 is now {tt.uio0.value()}')
    # print(f'uio1 is now {tt.uio1.value()}')
    # print(f'uio2 is now {tt.uio2.value()}')
    # print(f'uio3 is now {tt.uio3.value()}')
    # print(f'uio4 is now {tt.uio4.value()}')
    
    # tt.input_byte=0xAA   #dut.ui_in.value = 0xAA
    
    # for n in range(32):
        # tt.clock_project_once()
        # tt.input_byte= 1
        # print(f'Output is now {tt.output_byte:08b}')
        # print(f'Bidirs is now {tt.bidir_byte:08b}')
        # print(f'input is now {tt.input_byte:08b}')
    
    # for n in range(32):
        # tt.clock_project_once()
        # tt.input_byte= 1
        # print(f'Output is now {tt.output_byte:08b}')
        # print(f'Bidirs is now {tt.bidir_byte:08b}')
        # print(f'input is now {tt.input_byte:08b}')
    
    # for n in range(16):
        # tt.clock_project_once()
        # tt.input_byte= 1
        # print(f'Output is now {tt.output_byte:08b}')
        # print(f'Bidirs is now {tt.bidir_byte:08b}')
        # print(f'input is now {tt.input_byte:08b}')
    
    # tt.clock_project_once()
    # tt.bidir_byte = IDLE
    # tt.input_byte = 0xAA
    # tt.clock_project_once()
    # print(f'Output is now {tt.output_byte:08b}')
    # print(f'Bidirs is now {tt.bidir_byte:08b}')
    # print(f'input is now {tt.input_byte:08b}')
    # tt.clock_project_once()
    # print(f'Output is now {tt.output_byte:08b}')
    # print(f'Bidirs is now {tt.bidir_byte:08b}')
    # print(f'input is now {tt.input_byte:08b}')
