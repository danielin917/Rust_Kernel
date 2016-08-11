ENTRY(start)

SECTIONS {
	. = 1M;
	.boot :
	{
		KEEP(*(.multiboot_header)) /*ensures multiboot at beginning*/
	}

	.text :
	{
		*(.text)
	}
}
/*
 *Start is the entry point, bootloader will jump there after loading kernel
 *First address is set to 1 MiB
 *There are two output sections .boot and .text	all .text input sections
 *will be placed in the .text section while the multiboot header will be placed in boot
 */
