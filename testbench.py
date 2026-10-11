import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

MASK = 0xFFFFFFFF
NEG1, MIN_INT = MASK, 0x80000000

# ---------------------------------------------------------------- assembler
R_TYPE = {"add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2), "sltu": (0x00, 3),
          "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5), "or": (0x00, 6), "and": (0x00, 7)}
I_TYPE = {"addi": 0, "slli": 1, "slti": 2, "sltiu": 3, "xori": 4, "srli": 5, "srai": 5, "ori": 6, "andi": 7}
LOAD = {"lb": 0, "lw": 2}
STORE = {"sb": 0, "sw": 2}
BRANCH = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}
ALL = list(R_TYPE) + list(I_TYPE) + list(LOAD) + list(STORE) + list(BRANCH) + ["lui", "jal"]  # 31

names = {}   # machine word -> mnemonic, filled by asm() and used for coverage


def asm(op, *a):
    """Encode one instruction. Arguments follow assembly order, e.g. asm("lw", rd, offset, rs1)."""
    if op in R_TYPE:
        rd, rs1, rs2 = a
        f7, f3 = R_TYPE[op]
        w = f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x33
    elif op in I_TYPE:
        rd, rs1, imm = a
        imm = (imm & 0xFFF) | (0x400 if op == "srai" else 0)
        w = imm << 20 | rs1 << 15 | I_TYPE[op] << 12 | rd << 7 | 0x13
    elif op in LOAD:
        rd, imm, rs1 = a
        w = (imm & 0xFFF) << 20 | rs1 << 15 | LOAD[op] << 12 | rd << 7 | 0x03
    elif op in STORE:
        rs2, imm, rs1 = a
        imm &= 0xFFF
        w = (imm >> 5) << 25 | rs2 << 20 | rs1 << 15 | STORE[op] << 12 | (imm & 31) << 7 | 0x23
    elif op in BRANCH:
        rs1, rs2, imm = a
        imm &= 0x1FFF
        w = (imm >> 12) << 31 | ((imm >> 5) & 63) << 25 | rs2 << 20 | rs1 << 15 | BRANCH[op] << 12 \
            | ((imm >> 1) & 15) << 8 | ((imm >> 11) & 1) << 7 | 0x63
    elif op == "lui":
        rd, imm = a
        w = (imm & 0xFFFFF) << 12 | rd << 7 | 0x37
    else:  # jal
        rd, imm = a
        imm &= 0x1FFFFF
        w = (imm >> 20) << 31 | ((imm >> 1) & 0x3FF) << 21 | ((imm >> 11) & 1) << 20 \
            | ((imm >> 12) & 0xFF) << 12 | rd << 7 | 0x6F
    names[w] = op
    return w


# ---------------------------------------------------------------- directed cases
# Each case is (instruction, start state, expected changes).
# A state maps register -> value, plus "mem": {address: byte}. Expected may also hold "pc"
# (default 4). Anything not listed in the expectation must stay unchanged.
ALU = [  # (op, rs1, rs2, result)  ->  rd = x3, rs1 = x1, rs2 = x2
    ("add", 5, 7, 12), ("add", NEG1, 1, 0), ("sub", 5, 7, 0xFFFFFFFE),
    ("and", 0xF0F0, 0x0FF0, 0x00F0), ("or", 0xF0F0, 0x0FF0, 0xFFF0), ("xor", 0xF0F0, 0x0FF0, 0xFF00),
    ("sll", 1, 4, 16), ("sll", 1, 33, 2),                      # only the low 5 bits of rs2 are used
    ("srl", MIN_INT, 4, 0x08000000), ("sra", MIN_INT, 4, 0xF8000000),
    ("slt", NEG1, 1, 1), ("sltu", NEG1, 1, 0),                 # signed vs unsigned
]
IMM = [  # (op, rs1, immediate, result)
    ("addi", 10, -3, 7), ("slti", NEG1, 3, 1), ("sltiu", 1, -1, 1), ("xori", 0xFF, 0x0F, 0xF0),
    ("ori", 0xF0, 0x0F, 0xFF), ("andi", 0xFF, 0x0F, 0x0F), ("slli", 3, 4, 0x30),
    ("srli", MIN_INT, 4, 0x08000000), ("srai", MIN_INT, 4, 0xF8000000),
]
BRANCHES = [  # (op, rs1, rs2, taken)  ->  offset +8
    ("beq", 5, 5, 1), ("beq", 5, 6, 0), ("bne", 5, 6, 1), ("bne", 5, 5, 0),
    ("blt", NEG1, 1, 1), ("bge", NEG1, 1, 0), ("bltu", 1, NEG1, 1), ("bgeu", 1, NEG1, 0),
]
DIRECTED = (
    [(asm(op, 3, 1, 2), {1: a, 2: b}, {3: r}) for op, a, b, r in ALU]
    + [(asm(op, 3, 1, imm), {1: a}, {3: r}) for op, a, imm, r in IMM]
    + [(asm(op, 1, 2, 8), {1: a, 2: b}, {"pc": 8 if t else 4}) for op, a, b, t in BRANCHES]
    + [
        (asm("addi", 0, 1, 5), {1: 10}, {}),                                          # x0 stays 0
        (asm("lui", 3, 0x12345), {}, {3: 0x12345000}),
        (asm("lw", 3, 4, 1), {1: 8, "mem": {12: 0xBE, 13: 0xBA, 14: 0xFE, 15: 0xCA}}, {3: 0xCAFEBABE}),
        (asm("lb", 3, 2, 1), {1: 8, "mem": {10: 0x80}}, {3: 0xFFFFFF80}),             # sign-extended
        (asm("sw", 2, 8, 1), {1: 16, 2: 0xDEADBEEF},
         {"mem": {24: 0xEF, 25: 0xBE, 26: 0xAD, 27: 0xDE}}),
        (asm("sb", 2, 3, 1), {1: 16, 2: 0xDEADBEEF}, {"mem": {19: 0xEF}}),            # one byte only
        (asm("beq", 1, 2, -8), {1: 5, 2: 5}, {"pc": 0xFFFFFFF8}),                     # backwards
        (asm("jal", 5, 16), {}, {5: 4, "pc": 16}),                                    # x5 = return address
    ]
)


# ---------------------------------------------------------------- helpers
hits = dict.fromkeys(ALL, 0)


def value(handle):
    """Signal value as an int, or as a string like 'xxxx' if it has unknown bits."""
    try:
        return int(handle.value)
    except ValueError:
        return str(handle.value)


async def monitor(dut):
    """Count the instruction executing on each clock edge (reset low) for the coverage test."""
    while True:
        await RisingEdge(dut.clk)
        if value(dut.reset) == 0 and value(dut.instr) in names:
            hits[names[value(dut.instr)]] += 1


def start(dut):
    try:
        clk = Clock(dut.clk, 10, unit="ns")     # cocotb 2.x
    except TypeError:
        clk = Clock(dut.clk, 10, units="ns")    # cocotb 1.x
    cocotb.start_soon(clk.start())
    cocotb.start_soon(monitor(dut))


async def load(dut, program, state):
    """Reset the CPU, write the program at address 0, apply the start state, release reset."""
    dut.reset.value = 1
    await ClockCycles(dut.clk, 2)
    await FallingEdge(dut.clk)           # change inputs away from the rising edge
    for i, w in enumerate(program):
        for j in range(4):
            dut.imu.memory[4 * i + j].value = (w >> (8 * j)) & 0xFF
    for reg, v in state.items():
        if reg != "mem":
            dut.dpu.rfu.reg_mem[reg].value = v & MASK
    for addr, v in state.get("mem", {}).items():
        dut.dpu.dmu.data_mem[addr].value = v
    dut.reset.value = 0


async def step(dut):
    """One clock cycle, then wait for the outputs to settle."""
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)


def check(dut, state, expected):
    """Compare all registers and data memory with start state + expected changes."""
    errors = []
    for r in range(32):
        want = 0 if r == 0 else expected.get(r, state.get(r, r))    # registers reset to their number
        got = value(dut.dpu.rfu.reg_mem[r])
        if got != want:
            errors.append("x%d = %s, expected %s" % (r, got, want))
    mem = {**state.get("mem", {}), **expected.get("mem", {})}
    for a in range(128):
        got = value(dut.dpu.dmu.data_mem[a])
        if got != mem.get(a, 0):
            errors.append("mem[%d] = %s, expected %s" % (a, got, mem.get(a, 0)))
    return errors


async def run_one(dut, instr, state, expected):
    """Run a single instruction at address 0 and return a list of mismatches."""
    await load(dut, [instr], state)
    await step(dut)
    errors = check(dut, state, expected)
    want_pc = expected.get("pc", 4)
    if value(dut.pc) != want_pc:
        errors.append("pc = %s, expected %s" % (value(dut.pc), want_pc))
    return errors


def report(dut, label, errors):
    if errors:
        dut._log.error("FAIL  %s: %s", label, "; ".join(errors))
    else:
        dut._log.info("PASS  %s", label)
    return not errors


# ---------------------------------------------------------------- tests
@cocotb.test()
async def test_directed(dut):
    start(dut)
    failed = 0
    for n, (instr, state, expected) in enumerate(DIRECTED):
        errors = await run_one(dut, instr, state, expected)
        failed += not report(dut, "#%d %s" % (n, names[instr]), errors)
    assert failed == 0, "%d of %d directed cases failed" % (failed, len(DIRECTED))


def signed(x):
    return x - (1 << 32) if x >> 31 else x


def ref(op, a, b):
    """Python model of the ALU."""
    sh = b & 31
    result = {"add": a + b, "sub": a - b, "and": a & b, "or": a | b, "xor": a ^ b,
              "sll": a << sh, "srl": a >> sh, "sra": signed(a) >> sh,
              "slt": signed(a) < signed(b), "sltu": a < b}[op]
    return int(result) & MASK


@cocotb.test()
async def test_random_alu(dut):
    seed = int(os.environ.get("TB_SEED", 0)) or random.randrange(1, 1 << 30)
    rng = random.Random(seed)
    dut._log.info("seed = %d (set TB_SEED=%d to replay)", seed, seed)
    start(dut)

    def val():   # a quarter of the values are edge cases
        if rng.random() < 0.25:
            return rng.choice([0, 1, NEG1, MIN_INT, 0x7FFFFFFF])
        return rng.getrandbits(32)

    failed = 0
    for n in range(100):
        rd, rs1, rs2 = [rng.randint(1, 31) for _ in range(3)]
        if rng.random() < 0.5:                                  # R-type
            op = rng.choice(list(R_TYPE))
            state = {rs1: val(), rs2: val()}
            instr, expected = asm(op, rd, rs1, rs2), {rd: ref(op, state[rs1], state[rs2])}
        else:                                                   # I-type
            op = rng.choice(list(I_TYPE))
            imm = rng.randint(0, 31) if op in ("slli", "srli", "srai") else rng.randint(-2048, 2047)
            state = {rs1: val()}
            base = "sltu" if op == "sltiu" else op[:-1]         # addi -> add, slli -> sll, ...
            instr, expected = asm(op, rd, rs1, imm), {rd: ref(base, state[rs1], imm & MASK)}
        errors = await run_one(dut, instr, state, expected)
        if errors:
            failed += 1
            if failed <= 5:                                     # keep the log short
                report(dut, "#%d %s start=%s" % (n, op, state), errors)
    dut._log.info("random ALU: %d/100 passed", 100 - failed)
    assert failed == 0, "%d random cases failed (seed %d)" % (failed, seed)


def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a


@cocotb.test()
async def test_fibonacci(dut):
    """Compute fib(10) in x6 with a loop, store it at mem[0], then spin on a halt instruction."""
    program = [
        asm("addi", 5, 0, 10),    #  0: x5 = counter
        asm("addi", 6, 0, 0),     #  4: x6 = a = 0
        asm("addi", 7, 0, 1),     #  8: x7 = b = 1
        asm("beq", 5, 0, 20),     # 12: loop: if counter == 0, jump to 32
        asm("add", 7, 6, 7),      # 16: b = a + b
        asm("sub", 6, 7, 6),      # 20: a = b - a  (the old b)
        asm("addi", 5, 5, -1),    # 24: counter -= 1
        asm("jal", 0, -16),       # 28: back to the loop check
        asm("sw", 6, 0, 0),       # 32: mem[0] = a
        asm("jal", 0, 0),         # 36: halt (jump to itself)
    ]
    start(dut)
    await load(dut, program, {})
    for _ in range(200):
        await step(dut)
        if value(dut.pc) == 36:
            break
    assert value(dut.pc) == 36, "never reached the halt loop"
    assert value(dut.dpu.rfu.reg_mem[6]) == fib(10), "x6 = %s" % value(dut.dpu.rfu.reg_mem[6])
    stored = sum(value(dut.dpu.dmu.data_mem[i]) << (8 * i) for i in range(4))
    assert stored == fib(10), "mem[0] = %d" % stored


@cocotb.test()
async def test_coverage(dut):
    """Keep this test last: it reports what the earlier tests executed."""
    missing = [n for n in ALL if hits[n] == 0]
    percent = 100.0 * (len(ALL) - len(missing)) / len(ALL)
    dut._log.info("COVERAGE: %d/%d instructions (%.0f%%)", len(ALL) - len(missing), len(ALL), percent)
    if missing:
        dut._log.warning("never executed: %s", ", ".join(missing))
    assert percent >= float(os.environ.get("COV_GOAL", 100)), "coverage below goal"
