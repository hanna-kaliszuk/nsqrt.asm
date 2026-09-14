# NSQRT

An x86-64 assembly implementation of an integer square root for arbitrarily large non-negative integers. The function is callable from C and supports inputs of up to 256,000 bits.

---

## Description

The `nsqrt` function computes an `n`-bit integer `Q` such that:

```text
Q² ≤ X < (Q + 1)²
```

where `X` is a non-negative `2n`-bit integer.

The numbers are represented in memory as arrays of 64-bit words (`uint64_t`) in little-endian order. The parameter `n` must be a multiple of 64 and is restricted to the range from 64 to 256,000 bits.

The input value `X` may be modified during the computation and is used as working memory for the remainder of the algorithm.

---

## Algorithm

The square root is computed one bit at a time, starting from the most significant bit of the result.

For each iteration, the algorithm:

1. Constructs the comparison value `T` from the bits of the result computed so far.
2. Computes the bits of `T` directly when needed instead of storing the whole value.
3. Compares the current remainder `R` with `T`, starting from the most significant bit.
4. If `R ≥ T`, sets the next bit of `Q` and subtracts `T` from `R`.
5. Performs the subtraction bit by bit while propagating the borrow.

This approach allows the algorithm to operate on numbers much larger than the native 64-bit integer types without requiring a separate representation for intermediate values.

---

## Implementation

The implementation uses:

- **x86-64 assembly**
- **NASM**
- 64-bit words (`uint64_t`) for multi-word integer representation
- bit-level operations such as `bt`, `bts`, and `btr`
- C-compatible calling convention

The assembly source uses NASM macros to organize the main stages of the algorithm:

- `CLEAR_Q` — initializes the result
- `CALCULATE_R_BIT` — reads a bit from the current remainder
- `CALCULATE_T_BIT` — computes a bit of the comparison value
- `COMPARE` — compares `R` and `T`
- `SUBTRACT` — subtracts `T` from `R` with borrow handling
- `ITERATE` — performs the main iterations

---

## Function Prototype

```c
void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);
```

### Parameters

- `Q` — pointer to memory where the `n`-bit result will be stored.
- `X` — pointer to the input `2n`-bit integer. The memory may be modified during the computation and is used as working space.
- `n` — number of bits in the result. Must be a multiple of 64 and between 64 and 256,000.

If either pointer is `NULL`, or `n` is not a multiple of 64, the function performs no operation.

---

## Compilation

Assemble the source with NASM:

```bash
nasm -f elf64 -w+all -w+error -o nsqrt.o nsqrt.asm
```

The resulting object file can then be linked with a C program:

```bash
gcc -o main main.c nsqrt.o
```

---

## Usage Example

```c
#include <stdint.h>
#include <stdio.h>

void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);

int main(void) {
    uint64_t X[4] = {
        0xFFFFFFFFFFFFFFFF,
        0xFFFFFFFFFFFFFFFF,
        0,
        0
    };

    uint64_t Q[2] = {0, 0};
    unsigned n = 128;

    nsqrt(Q, X, n);

    printf("Result Q: 0x%016llx%016llx\n", Q[1], Q[0]);

    return 0;
}
```

Here, `X` contains a 256-bit input and `Q` provides space for the resulting 128-bit integer square root.

## Course

Developed as part of the **Computer Architecture and Operating Systems** course at the **University of Warsaw** during the summer semester of 2024/25.