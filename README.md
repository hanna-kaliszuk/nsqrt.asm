# NSQRT
An x86-64 assembly implementation of a function that computes the integer square root of a large non-negative number. The function is callable from C and supports numbers up to 256.000 bits. 
Part of the Computere Architecture and Operating Systems course realized in the summer semester of 2024/25 at the University of Warsaw. 

## DESCRIPTION
The function finds a non-negative `n`-bit integer `Q` such that:
```css
Q^2 <= X < (Q + 1)^2
```
where `X` is a 2n-bit non-negative integer. 

The numbers are represented in memory using little-endian orfer, with 64-bit words (`uint64_t`).

### FUNCTION PROTOTYPE
```c
void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);
```
Where:
- `uint64_t *Q` is a pointer to memory where the resulting integer square root will be stored. Must have enough space to store `n` bits
- `uint64_t *X` is a pointer to the input number in 2n-bit representation. This memory may be modified and can be used as working space
- `unsigned n` is a number of bits of the output square root. Must br a multiple of 64 and between 64 and 256.000

## COMPILATION
```bash
nasm -f elf64 -w+all -w+error -o nsqrt.o nsqrt.asm
```

Then link with a C program:
```bash
gcc -o main main.c nsqrt.o
```

### USAGE EXAMPLE IN C
```c
#include <stdint.h>
#include <stdio.h>

void nsqrt(uint64_t *Q, uint64_t *X, unsigned n);

int main() {
    uint64_t X[4] = {0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0, 0}; // 256-bit number
    uint64_t Q[2] = {0, 0}; // Will store 128-bit result
    unsigned n = 128;

    nsqrt(Q, X, n);

    printf("Result Q: 0x%016llx%016llx\n", Q[1], Q[0]);
    return 0;
}
```
