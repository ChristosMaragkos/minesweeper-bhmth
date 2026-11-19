.ifndef MY_MACROS_ASM
.equ    MY_MACROS_ASM, 1

.macro dma type, src, dst, len
ld     b, \type\()DMASRC
ld     a, \src
st     a, [b+]
ld     al, .pageof \src
st     al, [b+]

ld a, \dst
st a, [b+]
ld al, .pageof \dst
st al, [b+]

ld a, \len
st a, [b]

st al, [\type\()DMASTART]
.endm

.macro dma_reg_dst type, src, dst_page, dst_offs, len
ld     b, \type\()DMASRC
ld     a, \src
st     a, [b+]
ld     al, .pageof \src
st     al, [b+]

st \dst_offs\(), [b+]
st \dst_page\(), [b+]

ld a, \len
st a, [b]

st al, [\type\()DMASTART]
.endm

.macro vdma_vram src, dst, len
xor    al, al
st     al, [VDMACTRL]
dma    V, \src, \dst, \len
.endm

.macro vdma_cram src, dst, len
ld     al, 1
st     al, [VDMACTRL]
dma    V, \src, \dst, \len
.endm

.macro vdma_oam src, dst, len
ld     al, 0b10
st     al, [VDMACTRL]
dma    V, \src, \dst, \len
.endm

.macro adma src, dst, len
ld     b, ADMASRC
ld     a, \src
st     a, [b+]
ld     al, .pageof \src
st     al, [b+]

ld a, \dst
st a, [b+]

ld a, \len
st a, [b]

st al, [ADMASTART]
.endm

.macro sdma src, dst, len
dma    S, \src, \dst, \len
.endm

.macro vmp_write_word dst_reg, word_reg
ld al, 0b0011
ld b, VMPCTRL
st al, [b+]
xor al, al
st \dst_reg\(), [b+]
st al, [b+]
st \word_reg\(), [b]
.endm

.endif
