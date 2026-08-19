.text
.align 2

.globl _fast_hash_64

_fast_hash_64:
    // x0 = pointer to bytes
    // x1 = length
    // returns 64-bit rolling hash in x0
    mov x2, #0
    mov x3, #0

1:
    cbz x1, 2f
    ldrb w4, [x0], #1
    add x2, x2, x4
    add x3, x3, x4, lsl #1
    sub x1, x1, #1
    b 1b

2:
    add x0, x2, x3
    ret
