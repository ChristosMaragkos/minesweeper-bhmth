MEMORY
{
  wram : org = 0x000000, len = 0x040000
  stack : org = 0x040000, len = 0x010000
  rom : org = 0x060000, len = 0xC00000
  sram : org = 0xC60000, len = 0x040000
}

SECTIONS
{
  /* Cartridge ROM: This is the ONLY section written to the .bhm file */
  rom : {
    *(header)
    *(rom)
    *(.text)
    *(.rodata)
    *(.data)
  } > rom

  /* Uninitialized WRAM: variables get absolute addresses, no file payload */
  wram (NOLOAD) : {
    *(wram)
    *(.bss)
  } > wram

  /* Stack space */
  stack (NOLOAD) : {
    *(stack)
  } > stack

  sram (NOLOAD) : {
    *(sram)
  } > sram
}
