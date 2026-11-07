# RISC-V Processor with Hardware-Level Approximate Computing

A **32-bit single-cycle RV32I RISC-V processor** implemented in Verilog HDL and extended with hardware-level approximate arithmetic for error-tolerant workloads.

The processor integrates conventional exact arithmetic, a **Hardware-Efficient Approximate Adder (HEAA)**, and a **Hardware-Optimized and Error-Reduced Approximate Adder (HOERAA)** inside the ALU. A runtime `ApproxMode` signal selects the arithmetic behavior for eligible R-type `ADD` and `SUB` instructions.

The application workload is full-image **3×3 Sobel edge detection** using the 256×256 grayscale Cameraman image. The design deliberately keeps processor-control operations and non-arithmetic operations exact; approximation is applied only to the selected ADD/SUB datapath.

---

## Architecture

![RISC-V processor microarchitecture](architecture/arch.png)

The architecture contains four major levels:

1. **Image and memory interface** – the grayscale Cameraman image is converted into 32-bit memory words and loaded into data memory.
2. **RV32I processor core** – instruction memory, control unit, register file, ALU, PC logic, immediate generation, and data memory execute the Sobel program.
3. **Approximate ALU** – eligible `ADD`/`SUB` operations can use exact arithmetic, HEAA, or HOERAA according to `ApproxMode`.
4. **Application output** – the Sobel magnitude values are written back to memory and reconstructed as a 254×254 edge image.

Each instruction completes fetch, decode, execute, memory access, write-back, and next-PC selection in one clock cycle.



For the current implementation, the approximation mode is selected at the processor/ALU level and is applied to eligible R-type `ADD` and `SUB` instructions.

---

## Supported RV32I Instructions

| Type | Instructions |
| ---- | ------------ |
| **R-type** | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| **I-type ALU** | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| **Load** | LB, LH, LW, LBU, LHU |
| **Store** | SB, SH, SW |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| **Upper immediate** | LUI, AUIPC |
| **Jump** | JAL, JALR |

---

# Approximate Arithmetic Unit

**HEAA** stands for **Hardware-Efficient Approximate Adder**.

**HOERAA** stands for **Hardware-Optimized and Error-Reduced Approximate Adder**.

Both architectures divide the 32-bit addition into an **exact upper section** and an **approximate lower section**. The lower bits are simplified because errors in low-order bits have a smaller numerical impact than errors in high-order bits. This reduces the amount of carry-propagation logic while keeping the upper bits exact.

## Why approximate arithmetic is used

Approximate computing intentionally allows a controlled amount of numerical error in exchange for improved hardware characteristics such as reduced area, delay, power, or energy.

This is particularly suitable for **error-tolerant applications** such as image processing. In Sobel edge detection, a small arithmetic error does not necessarily destroy the useful edge information in an image. This creates an opportunity to replace part of an exact arithmetic datapath with simpler logic while measuring the resulting application-level degradation.

The key idea in this project is therefore:

```text
             Exact arithmetic
                   │
                   ▼
              Reference
                   │
          ┌────────┴────────┐
          ▼                 ▼
       HEAA mode        HOERAA mode
          │                 │
          ▼                 ▼
       Lower PPA        Lower PPA
       cost             cost
          │                 │
          └────────┬────────┘
                   ▼
          Measure image quality
```

The project does **not** assume that approximation is always acceptable. Each approximation mode must be characterized at both the arithmetic level and the application level.

---

## Approximate Arithmetic Modes

The processor input `ApproxMode` selects the arithmetic unit used by eligible R-type `ADD`/`SUB` instructions.

| Mode | `ApproxMode` | Description |
| ---- | :----------: | ----------- |
| Exact | `2'b00` | Conventional 32-bit addition/subtraction |
| HEAA-4 | `2'b01` | Four approximate least-significant bits and 28 exact upper bits |
| HOERAA-8 | `2'b10` | Eight approximate least-significant bits and 24 exact upper bits |
| Reserved | `2'b11` | Defaults safely to exact arithmetic |

---

## HEAA — Hardware-Efficient Approximate Adder

**Hardware-Efficient Approximate Adder (HEAA)** simplifies the least-significant part of an adder while keeping the most-significant part exact.

For an `N`-bit adder with `K` approximate LSBs, the structure can be viewed as:

```text
N-1                         K   K-1                 0
│                           │    │                  │
▼                           ▼    ▼                  ▼
┌───────────────────────────────┬────────────────────┐
│         EXACT MSB REGION      │  APPROXIMATE LSB   │
│            N-K bits            │       K bits       │
└───────────────────────────────┴────────────────────┘
                                │
                                └─ approximate carry
```

The important idea is that the lower `K` bits do not use a conventional full-adder chain. Instead, HEAA uses simple logic for these bits and approximates the carry entering the exact upper section.

### HEAA boundary carry

The carry from the approximate region into the exact region is approximated as:

```text
Ck = A[K-1] AND B[K-1]
```

The upper exact region then performs:

```text
Sum[N-1:K] = A[N-1:K] + B[N-1:K] + Ck
```

For the lower approximate bits:

```text
S[i] = A[i] OR B[i]       for 0 <= i <= K-2
```

The boundary bit uses a small MUX:

```text
S[K-1] = Ck ? 0 : (A[K-1] OR B[K-1])
```

Thus, HEAA removes carry propagation from most of the LSB region and replaces it with simple OR logic.

### HEAA-4 used in this project

For `K = 4`:

```text
31                         4 3 2 1 0
┌───────────────────────────┬─────────┐
│       EXACT: 28 bits      │ HEAA-4  │
│                           │  4 bits │
└───────────────────────────┴─────────┘
```

The logic is:

```text
C4 = A3 AND B3

S3 = C4 ? 0 : (A3 OR B3)
S2 = A2 OR B2
S1 = A1 OR B1
S0 = A0 OR B0

Sum[31:4] = A[31:4] + B[31:4] + C4
```

So the **lower 4 bits are approximate**, while the **upper 28 bits are calculated exactly**.

For example:

```text
A = 0000000F
B = 0000000F

Exact   = 0000001E  (30)
HEAA-4  = 00000017  (23)
```

The difference occurs because the lower 4-bit carry propagation has intentionally been approximated.

---

## HOERAA — Hardware-Optimized and Error-Reduced Approximate Adder

**Hardware-Optimized and Error-Reduced Approximate Adder (HOERAA)** uses a similar exact/approximate partition, but modifies the approximate region to achieve a different trade-off between hardware complexity and arithmetic error.

Like HEAA, the carry entering the exact upper region is approximated as:

```text
Ck = A[K-1] AND B[K-1]
```

The upper region therefore remains:

```text
Sum[N-1:K] = A[N-1:K] + B[N-1:K] + Ck
```

The main difference is in the approximate LSB region.

### HOERAA boundary logic

The most-significant approximate bit uses a MUX:

```text
S[K-1] =
    Ck ? (A[K-2] AND B[K-2])
       : (A[K-1] OR B[K-1])
```

Compared with HEAA, HOERAA does **not simply force the boundary bit to 0 when `Ck = 1`**. Instead, it uses the adjacent input bits `A[K-2]` and `B[K-2]` to make a better estimate.

The next approximate bit uses OR logic:

```text
S[K-2] = A[K-2] OR B[K-2]
```

The remaining lower bits are simplified to constant `1`:

```text
S[K-3:0] = 1
```

This removes even more logic from the lower part of the adder while the boundary MUX helps compensate for some of the resulting error.

### HOERAA-8 used in this project

For `K = 8`:

```text
31                         8 7 6 5 4 3 2 1 0
┌───────────────────────────┬───────────────────┐
│       EXACT: 24 bits      │  HOERAA: 8 bits   │
└───────────────────────────┴───────────────────┘
```

The approximate region consists of:

```text
C8 = A7 AND B7

S7 = C8 ? (A6 AND B6) : (A7 OR B7)
S6 = A6 OR B6
S5:S0 = 111111
```

while:

```text
Sum[31:8] = A[31:8] + B[31:8] + C8
```

Therefore, **8 LSBs are approximate** and **24 MSBs remain exact**.

### Why HOERAA can reduce error

The constant-1 lower bits simplify the hardware significantly, but they can introduce additional arithmetic error. HOERAA therefore uses the boundary MUX to preserve some information from the input operands.

For example, with:

```text
A = 0000000F
B = 0000000F
```

the exact result is:

```text
Exact = 0000001E  (30)
```

For a 4-bit HOERAA configuration, the boundary logic produces:

```text
HOERAA-4 = 0000001F  (31)
```

which has an error of only `+1`.

The exact error behavior depends on the input distribution, so the project evaluates HOERAA using both random arithmetic tests and the actual Sobel workload.

---

## HEAA vs HOERAA

| Feature | HEAA | HOERAA |
| --- | --- | --- |
| Full form | Hardware-Efficient Approximate Adder | Hardware-Optimized and Error-Reduced Approximate Adder |
| Exact upper region | Yes | Yes |
| Approximate lower region | Yes | Yes |
| Approximate boundary carry | `A[K-1] AND B[K-1]` | `A[K-1] AND B[K-1]` |
| Boundary bit | MUX between `0` and `A[K-1] OR B[K-1]` | MUX between `A[K-2] AND B[K-2]` and `A[K-1] OR B[K-1]` |
| Next approximate bit | OR | OR |
| Remaining lower bits | OR | Constant `1` |
| Main idea | Reduce carry-propagation hardware | Further simplify hardware while improving boundary error behavior |

The important distinction is that **HEAA primarily simplifies the lower adder using OR-based logic**, whereas **HOERAA simplifies the lower region further and adds boundary logic intended to reduce the resulting error**.

## Approximate SUB Operation

The Sobel workload requires subtraction as well as addition.

RV32I subtraction follows two's-complement arithmetic:

```text
A - B = A + (~B) + 1
```

Therefore, the same approximate adder structure can be reused for subtraction by controlling the second operand and the initial carry:

```text
ADD:
    X = B
    Cin = 0

SUB:
    X = ~B
    Cin = 1
```

Conceptually:

```text
             B[31:0]
                │
                ▼
             ┌─────┐
 SUB ───────►│ XOR │──── X[31:0]
             └─────┘
                │
                ▼
       Approximate/Exact Adder
                │
                ▼
              Result
```

For the approximate processor, `ADD` and `SUB` must be characterized separately because the input transformation for subtraction changes the operand patterns seen by the approximate logic.

The initial implementation should therefore verify:

- Exact ADD
- Exact SUB
- HEAA ADD
- HEAA SUB
- HOERAA ADD
- HOERAA SUB

before running the complete Sobel workload.

---

## Runtime Approximation Selection

The ALU receives a mode signal:

```text
ApproxMode
```

The intended behavior is:

```text
ApproxMode = 00 → Exact
ApproxMode = 01 → HEAA-4
ApproxMode = 10 → HOERAA-8
ApproxMode = 11 → Exact fallback
```

Conceptually:

```text
                     A[31:0]
                        │
                     B[31:0]
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
        Exact ADD/SUB       Approx ADD/SUB
                                  │
                           ┌──────┴──────┐
                           │ HEAA/HOERAA │
                           └──────┬──────┘
                                  │
                    ApproxMode ───┤
                                  ▼
                                MUX
                                  │
                                  ▼
                              ALU result
```

Only eligible arithmetic operations use this selection. This prevents approximate arithmetic from unintentionally corrupting control-flow or memory-address calculations.

---

# Sobel Edge Detection Workload

The processor executes a 3×3 Sobel operator using only RV32I-friendly arithmetic:

```text
Gx = (P2 - P0) + 2(P5 - P3) + (P8 - P6)
Gy = (P6 - P0) + 2(P7 - P1) + (P8 - P2)

Magnitude = |Gx| + |Gy|
```

The multiplication by 2 is implemented as a shift/add operation, so RV32M multiplication is not required.

The workload uses a 256×256 grayscale Cameraman image and produces a 254×254 edge image because the implementation uses a valid 3×3 window without padding. The first and last image rows and columns cannot act as the center of a complete 3×3 neighborhood.

### Memory map

One grayscale pixel is stored in each 32-bit word to keep the first hardware validation straightforward.

| Region | Byte address | Contents |
| ------ | ------------ | -------- |
| Input image | `0x00000` onward | 256 × 256 grayscale pixels |
| Sobel output | `0x40000` onward | 254 × 254 magnitude values |

The data memory uses 131,072 32-bit words (512 KiB), which holds both buffers.

---

# Results

## Golden reference

![Golden Sobel reference](reference_image/golden_output.png)

## Exact Sobel output

![Exact Sobel output](output/rtl_output.png)

## HEAA Sobel output

![HEAA Sobel output](output/rtl_output_heaa.png)

## HOERAA Sobel output

![HOERAA Sobel output](output/rtl_output_hoeraa.png)

The included output images allow visual comparison of exact and approximate arithmetic. Formal image-quality metrics such as MAE, MSE, PSNR, and SSIM should be used to quantify the application-level error.




---

## Project Structure

```text
RISC-V-Processor-Hardware-Level-Approximate-Computing/
│
├── architecture/
│   └── arch.png                     # Processor + approximate ALU architecture
│
├── rtl/
│   ├── processor.v                  # Top-level RV32I processor
│   ├── ALU.v                        # ALU with approximate ADD/SUB integration
│   ├── ALU_control_unit.v
│   ├── main_control_unit.v
│   ├── PC.v
│   ├── PC_adder.v
│   ├── adder.v
│   ├── data_memory.v                # 512 KiB word-addressed memory
│   ├── instruction_mem.v
│   ├── register_file.v
│   ├── imm_gen.v
│   ├── mux.v
│   ├── mux4to1.v
│   ├── program.mem                  # Sobel RV32I program
│   ├── data.mem                     # Cameraman input-memory initialization
│   │
│   ├── approximate/
│   │   ├── heaa_adder.v
│   │   ├── hoeraa_adder.v
│   │   └── approx_add_sub_unit.v
│   │
│   └── tb/
│       └── tb_sobel_full.v          # Full-image Sobel testbench
│
├── scripts/
│   ├── generate_full_sobel_rv32i.py
│   ├── prepare_full_sobel_image.py
│   └── render_rtl_sobel_full.py
│
├── reference_image/
│   ├── cameraman.bmp
│   └── golden_output.png
│
├── output/
│   ├── rtl_output.png
│   ├── rtl_output_heaa.png
│   └── rtl_output_hoeraa.png
│
└── README.md
```

---

## References

1. RISC-V International, *The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture*. https://docs.riscv.org/

2. P. Balasubramanian and D. Maskell, “Hardware Efficient Approximate Adder Design,” *2018 IEEE Region 10 Conference (TENCON)*, 2018, pp. 806–811. DOI: 10.1109/TENCON.2018.8650127.

3. P. Balasubramanian and D. L. Maskell, “Hardware Optimized and Error Reduced Approximate Adder,” *Electronics*, vol. 8, no. 11, art. 1212, 2019. DOI: 10.3390/electronics8111212.

4. I. Sobel, “An Isotropic 3×3 Image Gradient Operator,” Stanford Artificial Intelligence Project, 1968.

The HEAA and HOERAA descriptions above follow the published architecture descriptions. In particular, HOERAA uses a MUX whose inputs are `(A[K−1] OR B[K−1])` and `(A[K−2] AND B[K−2])`, selected by `(A[K−1] AND B[K−1])`, while the lower `K−2` outputs are tied to `1`.
