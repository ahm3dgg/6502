package main

import "ines"

import rl "vendor:raylib"
import "core:time"
import "core:math/rand"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:io"
import "core:bytes"

CROSS :: 1
BRANCH :: 1
STACK_START :: 0x0100

ROM_START 			:: 0x8000
ROM_START_MAPPED 	:: 0xC000
ROM_END_MAPPED 		:: 0xFFFF

bit0 :: (1 << 0)
bit1 :: (1 << 1)
bit2 :: (1 << 2)
bit3 :: (1 << 3)
bit4 :: (1 << 4)
bit5 :: (1 << 5)
bit6 :: (1 << 6)
bit7 :: (1 << 7)

PPU_CTRL   :: 	0x2000
PPU_MASK   :: 	0x2001
PPU_STATUS :: 	0x2002
OAM_ADDR   :: 	0x2003
OAM_DATA   :: 	0x2004
PPU_SCROLL :: 	0x2005
PPU_ADDR   :: 	0x2006
PPU_DATA   :: 	0x2007
OAM_DMA    :: 	0x4014

Status :: enum u8 {
	Carry = 0, 
	Zero, 
	InterruptDisable, 
	Decimal, 
	B,
	One,
	Overflow, 
	Negative
}

Opcode :: enum {
	LDA = 0, TAX, PHA, ASL,
	AND, ADC, DEC, BRK,
	BCC, CLC, NOP, LDX, 
	TAY, PHP, LSR, BIT, 
	CMP, DEX, JMP, BCS, 
	CLD, LDY, TSX, PLA, 
	ROL, EOR, CPX, DEY, 
	JSR, BEQ, CLI, STA, 
	TXA, PLP, ROR, ORA,
	CPY, INC, RTI, BMI, 
	CLV, STX, TXS, SBC, 
	INX, RTS, BNE, SEC, 
	STY, TYA, INY, BPL, 
	SED, BVC, SEI, BVS,
	LAX, SAX, DCP, ISB, 
	SLO, RLA, SRE, RRA 
}

AddressingMode :: enum {
	Implied = 0,
	Accumulator,	  		  // A
	Immediate,	      		  // #$n
	Absolute, 		  		  // $nnnn	
	XIndexedAbsolute, 		  // $nnnn,X
	YIndexedAbsolute, 	      // $nnnn,Y
	AbsoluteIndirect, 	  	  // ($nnnn)
	ZeroPage, 	      		  // $nn
	XIndexedZeroPage,         // $nn,X
	YIndexedZeroPage, 		  // $nn,Y
	XIndexedZeroPageIndirect, // ($nn,X)
	ZeroPageIndirectYIndexed, // $(nn), Y
	Relative				  // $nnnn
}

MemoryRegion :: enum {
	None = 0,
	WRAM,
	PPU, 
	APU,
	JOY1, 
	JOY2,
	CRAM,
	ROM, 
}

snake_game: []byte = {
	0x20, 0x06, 0x06, 0x20, 0x38, 0x06, 0x20, 0x0d, 0x06, 0x20, 0x2a, 0x06, 0x60, 0xa9, 0x02, 0x85,
    0x02, 0xa9, 0x04, 0x85, 0x03, 0xa9, 0x11, 0x85, 0x10, 0xa9, 0x10, 0x85, 0x12, 0xa9, 0x0f, 0x85,
    0x14, 0xa9, 0x04, 0x85, 0x11, 0x85, 0x13, 0x85, 0x15, 0x60, 0xa5, 0xfe, 0x85, 0x00, 0xa5, 0xfe,
    0x29, 0x03, 0x18, 0x69, 0x02, 0x85, 0x01, 0x60, 0x20, 0x4d, 0x06, 0x20, 0x8d, 0x06, 0x20, 0xc3,
    0x06, 0x20, 0x19, 0x07, 0x20, 0x20, 0x07, 0x20, 0x2d, 0x07, 0x4c, 0x38, 0x06, 0xa5, 0xff, 0xc9,
    0x77, 0xf0, 0x0d, 0xc9, 0x64, 0xf0, 0x14, 0xc9, 0x73, 0xf0, 0x1b, 0xc9, 0x61, 0xf0, 0x22, 0x60,
    0xa9, 0x04, 0x24, 0x02, 0xd0, 0x26, 0xa9, 0x01, 0x85, 0x02, 0x60, 0xa9, 0x08, 0x24, 0x02, 0xd0,
    0x1b, 0xa9, 0x02, 0x85, 0x02, 0x60, 0xa9, 0x01, 0x24, 0x02, 0xd0, 0x10, 0xa9, 0x04, 0x85, 0x02,
    0x60, 0xa9, 0x02, 0x24, 0x02, 0xd0, 0x05, 0xa9, 0x08, 0x85, 0x02, 0x60, 0x60, 0x20, 0x94, 0x06,
    0x20, 0xa8, 0x06, 0x60, 0xa5, 0x00, 0xc5, 0x10, 0xd0, 0x0d, 0xa5, 0x01, 0xc5, 0x11, 0xd0, 0x07,
    0xe6, 0x03, 0xe6, 0x03, 0x20, 0x2a, 0x06, 0x60, 0xa2, 0x02, 0xb5, 0x10, 0xc5, 0x10, 0xd0, 0x06,
    0xb5, 0x11, 0xc5, 0x11, 0xf0, 0x09, 0xe8, 0xe8, 0xe4, 0x03, 0xf0, 0x06, 0x4c, 0xaa, 0x06, 0x4c,
    0x35, 0x07, 0x60, 0xa6, 0x03, 0xca, 0x8a, 0xb5, 0x10, 0x95, 0x12, 0xca, 0x10, 0xf9, 0xa5, 0x02,
    0x4a, 0xb0, 0x09, 0x4a, 0xb0, 0x19, 0x4a, 0xb0, 0x1f, 0x4a, 0xb0, 0x2f, 0xa5, 0x10, 0x38, 0xe9,
    0x20, 0x85, 0x10, 0x90, 0x01, 0x60, 0xc6, 0x11, 0xa9, 0x01, 0xc5, 0x11, 0xf0, 0x28, 0x60, 0xe6,
    0x10, 0xa9, 0x1f, 0x24, 0x10, 0xf0, 0x1f, 0x60, 0xa5, 0x10, 0x18, 0x69, 0x20, 0x85, 0x10, 0xb0,
    0x01, 0x60, 0xe6, 0x11, 0xa9, 0x06, 0xc5, 0x11, 0xf0, 0x0c, 0x60, 0xc6, 0x10, 0xa5, 0x10, 0x29,
    0x1f, 0xc9, 0x1f, 0xf0, 0x01, 0x60, 0x4c, 0x35, 0x07, 0xa0, 0x00, 0xa5, 0xfe, 0x91, 0x00, 0x60,
    0xa6, 0x03, 0xa9, 0x00, 0x81, 0x10, 0xa2, 0x00, 0xa9, 0x01, 0x81, 0x10, 0x60, 0xa2, 0x00, 0xea,
    0xea, 0xca, 0xd0, 0xfb, 0x60
}

Instruction :: struct {
	opcode_s: string,
	opcode: Opcode,
	addrmode: AddressingMode,
	readmem: bool,
	cycles: u64, 
	check_cross: bool,
	illegal: bool,
	size: u8
}

Cpu :: struct {
	x: byte,
	y: byte,
	a: byte,
	pc: u16,
	sp: u8,	/* $0100-$01FF */
	status: bit_set[Status],
	clock: u64,
	nes: ^NES
}

Cartidage :: struct {
	mapper: 	ines.Mapper,
	bank_count: uint,
	prg_rom: 	[]byte,
	chr_rom: 	[]byte,
}

cart_cpu_read :: proc(cart: ^Cartidage, addr: u16) -> u8 { 
	#partial switch cart.mapper {
		case .Mapper0:
			mapped_addr := mapper0_cpu_map(cart.bank_count, addr)
			return cart.prg_rom[mapped_addr]
		case: return 0
	}
}

cart_ppu_read :: proc(cart: ^Cartidage, addr: u16) -> u8 {
	#partial switch cart.mapper {
		case .Mapper0: 
			mapped_addr := mapper0_ppu_map(addr)
			return cart.chr_rom[mapped_addr]
		case: return 0
	}
}

ppu_read :: proc(ppu: ^PPU, addr: u16) -> u8 { 
	switch {
		case addr == PPU_DATA:
			if !ppu.primed {
				dummy := ppu.ppu_data 							// read the old value 
				ppu.ppu_data = nes_read(ppu.nes, ppu.ppu_addr)	// read the data from the CHR-ROM
				ppu.primed = !ppu.primed 						// toggle 'primed'
				ppu.ppu_addr += 1    							// increment the PPUADDR by 1
				return dummy 									// return the old data
			} else {
				ppu.primed = !ppu.primed
				return ppu.ppu_data
			}
		case: return 0
	}
}

/*
 LDA #$06
 STA $2006
 LDA #$00
 STA $2006

 writing at address 0x0600
*/

ppu_write :: proc(ppu: ^PPU, addr: u16, data: u8) {		

	switch {
		case addr == PPU_ADDR:
			if ppu.toggle_write {
				ppu.ppu_addr |= u16(data)
			} else {
				ppu.ppu_addr = u16(data) << 8
			}
			ppu.toggle_write = !ppu.toggle_write	

		case addr == PPU_DATA: 
			ppu.ppu_data = data
			ppu.ppu_addr += 1
	}
}

PPU :: struct {	
	vram: [2048]byte,
	palette: [64]byte,
	
	// Registers
	ppu_addr: u16,
	ppu_ctrl: u8,
	ppu_mask: u8,
	ppu_status: u8,
	ppu_data: u8,
	primed: bool,

	toggle_write: bool,
	
	clock_counter: u64,
	nes: ^NES
}

APU :: struct {}

NES :: struct {
	cpu:  ^Cpu,	
	ppu:  ^PPU,
	cart: ^Cartidage,
	apu:  ^APU,
	ram:  [2048]byte,
}

rng: u8 = 2
last_pressed_button: rune

nes_reset :: proc(nes: ^NES) {
	nes.cpu = {}
	nes.cpu.sp = 0xFD
	nes.cpu.pc = 0x600
	nes.cpu.status = {.One, .InterruptDisable}
}

nes_read :: proc(nes: ^NES, addr: u16) -> u8 {

	switch {
		case addr == 0xFE: 
			return u8(rand.int31())
		case addr == 0xFF: 
			return u8(last_pressed_button)
		case addr >= 0 && addr <= 0x05FF:
			return nes.ram[addr]
		case addr >= 0x0600: 
			return snake_game[addr - 0x600]
		case: panic("invalid address")
	}

	switch {
		case addr >= 0x0000 && addr <= 0x1FFF: 
			return nes.ram[addr & 0x07FF];
		case addr >= 0x2000 && addr <= 0x3FFF:
			return ppu_read(nes.ppu, addr)
		case addr >= 0x8000 && addr <= 0xFFFF: 
			return cart_cpu_read(nes.cart, addr)
		case addr >= 0x4000 && addr <= 0x4017: 
			return 0xFF
		case: fmt.println("Invalid Address"); return 0;
	}

}

nes_write :: proc(nes: ^NES, addr: u16, data: u8) {
	switch {
		case addr >= 0 && addr <= 0x05FF:
			nes.ram[addr] = data
		case: nes_reset(nes)
	}

	switch {
		case addr >= 0x0000 && addr <= 0x1FFF: 
			nes.ram[addr & 0x07FF] = data;
		case addr >= 0x2000 && addr <= 0x3FFF:
			ppu_write(nes.ppu, addr, data)
		case:
	}
}

cpu_read :: proc(cpu: ^Cpu, addr: u16) -> u8 {
	return nes_read(cpu.nes, addr)
}

cpu_write :: proc(cpu: ^Cpu, addr: u16, data: u8) {
	nes_write(cpu.nes, addr, data)
}

cpu_update_status :: proc(cpu: ^Cpu, flag: Status, condition: bool) {
	if condition {
		cpu.status += {flag} 
	} else {
		cpu.status -= {flag}
	}
}

adc :: proc (cpu: ^Cpu, arg: u8) {
	carry := .Carry in cpu.status ? u8(1) : u8(0)
	sum := uint(cpu.a) + uint(arg) + uint(carry)

	// There is an overflow if the inputs do not have different signs, 
	// and the input sign is different from the output sign. 
	// overflow := (~(cpu.a ~ arg) & (cpu.a ~ u8(sum))) & 0x80 != 0 

	overflow := (u8(sum) ~ cpu.a) & (u8(sum) ~ arg) & 0x80

	cpu_update_status(cpu, .Carry, sum > 0xff)
	cpu_update_status(cpu, .Overflow, overflow != 0)
	cpu_update_status(cpu, .Zero, u8(sum) == 0)
	cpu_update_status(cpu, .Negative, u8(sum) & 0x80 != 0)

	cpu.a = u8(sum)
}

lda :: proc(cpu: ^Cpu, arg: u8) {
	cpu.a = arg
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)	
}

ldx :: proc(cpu: ^Cpu, arg: u8) {
	cpu.x = arg
	cpu_update_status(cpu, .Zero, cpu.x == 0)
	cpu_update_status(cpu, .Negative, cpu.x & 0x80 != 0)	
}

ldy :: proc(cpu: ^Cpu, arg: u8) {
	cpu.y = arg
	cpu_update_status(cpu, .Zero, cpu.y == 0)
	cpu_update_status(cpu, .Negative, cpu.y & 0x80 != 0)	
}

sta :: proc(cpu: ^Cpu, addr: u16) {
	cpu_write(cpu, addr, cpu.a)
}

stx :: proc(cpu: ^Cpu, addr: u16) {
	cpu_write(cpu, addr, cpu.x)
}

sty :: proc(cpu: ^Cpu, addr: u16) {
	cpu_write(cpu, addr, cpu.y)
}

tax :: proc(cpu: ^Cpu) {
	cpu.x = cpu.a
	cpu_update_status(cpu, .Zero, cpu.x == 0)
	cpu_update_status(cpu, .Negative, cpu.x & 0x80 != 0)	
}

tay :: proc(cpu: ^Cpu) {
	cpu.y = cpu.a
	cpu_update_status(cpu, .Zero, cpu.y == 0)
	cpu_update_status(cpu, .Negative, cpu.y & 0x80 != 0)
}

tsx :: proc(cpu: ^Cpu) {
	cpu.x = cpu.sp
	cpu_update_status(cpu, .Zero, cpu.x == 0)
	cpu_update_status(cpu, .Negative, cpu.x & 0x80 != 0)
}

txa :: proc(cpu: ^Cpu) {
	cpu.a = cpu.x
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)
}

txs :: proc(cpu: ^Cpu) {
	cpu.sp = cpu.x 	
}

tya :: proc(cpu: ^Cpu) {
	cpu.a = cpu.y
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)
}

pha :: proc(cpu: ^Cpu) {	
	cpu_write(cpu, STACK_START + u16(cpu.sp), cpu.a)
	cpu.sp -= 1
}

php :: proc(cpu: ^Cpu) {
	status := transmute(u8)(cpu.status +  {.B}) 
	cpu_write(cpu, STACK_START + u16(cpu.sp), status)
	cpu.sp -= 1
}

pla :: proc(cpu: ^Cpu) {
	cpu.sp += 1
	cpu.a = cpu_read(cpu, STACK_START + u16(cpu.sp))
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)	
}

plp :: proc(cpu: ^Cpu) {
	cpu.sp += 1
	status := cpu_read(cpu, STACK_START + u16(cpu.sp))
	cpu.status = transmute(bit_set[Status])(status) - {.B}
	cpu.status += {.One}
}

asl :: proc(cpu: ^Cpu, use_accumulator: bool, addr: u16) {
	arg, result: u8

	if use_accumulator {
		arg = cpu.a
		result = cpu.a << 1
		cpu.a = result
	} else {
		arg = cpu_read(cpu, addr)
		result = arg << 1
		cpu_write(cpu, addr, result)
	}

	cpu_update_status(cpu, .Negative, result & 0x80 != 0) // result bit 7 
	cpu_update_status(cpu, .Carry, arg & 0x80 != 0) // value bit 7 
	cpu_update_status(cpu, .Zero, result == 0) // result == 0 
}

lsr :: proc(cpu: ^Cpu, use_accumulator: bool, addr: u16) {
	arg, result: u8

	if use_accumulator {
		arg = cpu.a
		result = cpu.a >> 1
		cpu.a = result
	} else {
		arg = cpu_read(cpu, addr)
		result = arg >> 1
		cpu_write(cpu, addr, result)
	}

	cpu_update_status(cpu, .Carry, arg & 1 != 0) // value bit 0 
	cpu_update_status(cpu, .Zero, result == 0) // result == 0 
	cpu_update_status(cpu, .Negative, result & 0x80 != 0) // result bit 7 
}

rol :: proc(cpu: ^Cpu, use_accumulator: bool, addr: u16) {
	arg, result: u8
	carry := .Carry in cpu.status ? u8(1) : u8(0)

	if use_accumulator {
		arg = cpu.a
		result = (cpu.a << 1) | carry
		cpu.a = result
	} else {
		arg = cpu_read(cpu, addr)
		result = (arg << 1) | carry
		cpu_write(cpu, addr, result)
	}

	cpu_update_status(cpu, .Carry, arg & 0x80 != 0) // value bit 7 
	cpu_update_status(cpu, .Negative, result & 0x80 != 0) // result bit 7 
	cpu_update_status(cpu, .Zero, result == 0) // result == 0 
}

ror :: proc(cpu: ^Cpu, use_accumulator: bool, addr: u16) {
	arg, result: u8
	carry := .Carry in cpu.status ? u8(1) : u8(0)

	if use_accumulator {
		arg = cpu.a
		result = (carry << 7) | (cpu.a >> 1) 
		cpu.a = result
	} else {
		arg = cpu_read(cpu, addr)
		result = (carry << 7) | (arg >> 1)
		cpu_write(cpu, addr, result)
	}

	cpu_update_status(cpu, .Carry, arg & 1 != 0) // value bit 0 
	cpu_update_status(cpu, .Negative, result & 0x80 != 0) // result bit 7 
	cpu_update_status(cpu, .Zero, result == 0) // result == 0 
}

inc :: proc(cpu: ^Cpu, addr: u16) {
	result := cpu_read(cpu, addr) + 1
	cpu_write(cpu, addr, result)

	cpu_update_status(cpu, .Zero, result == 0)
	cpu_update_status(cpu, .Negative, result & 0x80 != 0)
}

and :: proc(cpu: ^Cpu, arg: u8) {
	cpu.a &= arg
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)	
}

bit :: proc(cpu: ^Cpu, arg: u8) {
	result := cpu.a & arg
	cpu_update_status(cpu, .Negative, arg & 0x80 != 0)
	cpu_update_status(cpu, .Overflow, arg & (1 << 6) != 0)
	cpu_update_status(cpu, .Zero, result == 0)
}

eor :: proc(cpu: ^Cpu, arg: u8) {
	cpu.a ~= arg
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)
}

ora :: proc(cpu: ^Cpu, arg: u8) {
	cpu.a |= arg
	cpu_update_status(cpu, .Zero, cpu.a == 0)
	cpu_update_status(cpu, .Negative, cpu.a & 0x80 != 0)
}

cmp :: proc(cpu: ^Cpu, arg: u8) {
	result := cpu.a - arg
	cpu_update_status(cpu, .Zero, cpu.a == arg)
	cpu_update_status(cpu, .Negative, result & 0x80 != 0)
	cpu_update_status(cpu, .Carry, cpu.a >= arg)
}

cpx :: proc(cpu: ^Cpu, arg: u8) {
	result := cpu.x - arg
	cpu_update_status(cpu, .Zero, cpu.x == arg)
	cpu_update_status(cpu, .Negative, result & 0x80 != 0)
	cpu_update_status(cpu, .Carry, cpu.x >= arg)
}

cpy :: proc(cpu: ^Cpu, arg: u8) {
	result := cpu.y - arg
	cpu_update_status(cpu, .Zero, cpu.y == arg)
	cpu_update_status(cpu, .Negative, result & 0x80 != 0)
	cpu_update_status(cpu, .Carry, cpu.y >= arg)
}

dec :: proc(cpu: ^Cpu, addr: u16) {
	result := cpu_read(cpu, addr) - 1
	cpu_write(cpu, addr, result)

	cpu_update_status(cpu, .Zero, result == 0)
	cpu_update_status(cpu, .Negative, result & 0x80 != 0)
}

dex :: proc(cpu: ^Cpu) {
	cpu.x -= 1
	cpu_update_status(cpu, .Zero, cpu.x == 0)
	cpu_update_status(cpu, .Negative, cpu.x & 0x80 != 0)
}

dey :: proc(cpu: ^Cpu) {
	cpu.y -= 1
	cpu_update_status(cpu, .Zero, cpu.y == 0)
	cpu_update_status(cpu, .Negative, cpu.y & 0x80 != 0)
}

inx :: proc(cpu: ^Cpu) {
	cpu.x += 1
	cpu_update_status(cpu, .Zero, cpu.x == 0)
	cpu_update_status(cpu, .Negative, cpu.x & 0x80 != 0)
}

iny :: proc(cpu: ^Cpu) {
	cpu.y += 1
	cpu_update_status(cpu, .Zero, cpu.y == 0)
	cpu_update_status(cpu, .Negative, cpu.y & 0x80 != 0)
}

jmp :: proc(cpu: ^Cpu, target: u16) {
	cpu.pc = target
}

jsr :: proc(cpu: ^Cpu, target: u16) {
	saved_pc := cpu.pc - 1
	
	cpu_write(cpu, STACK_START + u16(cpu.sp), u8(saved_pc >> 8))
	cpu_write(cpu, STACK_START + u16(cpu.sp - 1), u8(saved_pc))

	cpu.sp -= 2
	cpu.pc = target
}

rts :: proc(cpu: ^Cpu) {
	cpu.sp += 2
	high := u16(cpu_read(cpu, STACK_START + u16(cpu.sp)))
	low := u16(cpu_read(cpu, STACK_START + u16(cpu.sp - 1)))
	cpu.pc = (high << 8) | low + 1
}

sec :: proc(cpu: ^Cpu) {
	cpu.status += {.Carry}
}

sed :: proc(cpu: ^Cpu) {
	cpu.status += {.Decimal}
}

sei :: proc(cpu: ^Cpu) {
	cpu.status += {.InterruptDisable}
}

bcc :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {	
	if .Carry not_in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bcs :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Carry in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

beq :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Zero in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bmi :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Negative in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bne :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Zero not_in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bpl :: proc(cpu: ^Cpu, instr: ^Instruction,  target: u16) {
	if .Negative not_in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bvc :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Overflow not_in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

bvs :: proc(cpu: ^Cpu, instr: ^Instruction, target: u16) {
	if .Overflow in cpu.status {
		cpu.pc = target
	} else {
		instr.cycles = 2
	}
}

clc :: proc(cpu: ^Cpu) {
	cpu.status -= {.Carry}
}

cld :: proc(cpu: ^Cpu) {
	cpu.status -= {.Decimal}
}

cli :: proc(cpu: ^Cpu) {
	cpu.status -= {.InterruptDisable}
}

clv :: proc(cpu: ^Cpu) {
	cpu.status -= {.Overflow}
}

rti :: proc(cpu: ^Cpu) {
	// pull NVxxDIZC flags from stack
	plp(cpu)
	cpu.status += {.InterruptDisable}

	// pull PC from stack 
	cpu.sp += 2
	high := u16(cpu_read(cpu, STACK_START + u16(cpu.sp)))
	low := u16(cpu_read(cpu, STACK_START + u16(cpu.sp - 1)))
	cpu.pc = (high << 8) | low 
}

lax :: proc(cpu: ^Cpu, arg: u8) {
	cpu.a = arg 
	cpu.x = arg
	
	cpu_update_status(cpu, .Zero, arg == 0)
	cpu_update_status(cpu, .Negative, arg & 0x80 != 0)
}

sax :: proc(cpu: ^Cpu, addr: u16) {
	cpu_write(cpu, addr, cpu.x & cpu.a)
} 

dcp :: proc(cpu: ^Cpu, addr: u16) {

	dec(cpu, addr)
	cmp(cpu, cpu_read(cpu, addr))
}

isb :: proc(cpu: ^Cpu, addr: u16) {
    inc(cpu, addr)
    adc(cpu, ~cpu_read(cpu, addr))
}

slo :: proc(cpu: ^Cpu, addr: u16) {
	asl(cpu, false, addr)
	ora(cpu, cpu_read(cpu, addr))
}

rla :: proc(cpu: ^Cpu, addr: u16) {
	rol(cpu, false, addr)
	and(cpu, cpu_read(cpu, addr))
}

sre :: proc(cpu: ^Cpu, addr: u16) {
	lsr(cpu, false, addr)
	eor(cpu, cpu_read(cpu, addr))
}

rra :: proc(cpu: ^Cpu, addr: u16) {
	ror(cpu, false, addr)
	adc(cpu, cpu_read(cpu, addr))
}

cpu_init :: proc(cpu: ^Cpu) {
	cpu.status += {.InterruptDisable, .One}
	cpu.pc = 0x0600
	cpu.sp = 0xFD
}

CPUDebugContext :: struct {
	cpu: ^Cpu,
	instr_bytes: [3]byte,
	instr: Instruction,
	arg: u16,
}

cpu_log :: proc(cpu_debug_ctx: CPUDebugContext) {
	cpu := cpu_debug_ctx.cpu
	instr := cpu_debug_ctx.instr
	instr_bytes := cpu_debug_ctx.instr_bytes
	arg := cpu_debug_ctx.arg

	logLine := strings.builder_make()

	fmt.sbprintf(&logLine, "%4X  ", cpu.pc)

	if instr.size == 3 { 
		fmt.sbprintf(&logLine, "%2X %2X %2X ", instr_bytes[0], instr_bytes[1], instr_bytes[2])
	} else if instr.size == 2 {
		fmt.sbprintf(&logLine, "%2X %2X    ", instr_bytes[0], instr_bytes[1])
	} else if instr.size == 1 {
		fmt.sbprintf(&logLine, "%2X       ", instr_bytes[0])
	}
	
	if instr.illegal {
		fmt.sbprintf(&logLine, "*%s ", instr.opcode_s)	
	} else {
		fmt.sbprintf(&logLine, "%s ", instr.opcode_s)	
	}

	#partial switch instr.addrmode {
		case .Immediate:
			fmt.sbprintf(&logLine, "#$%2X\t\t\t", arg)
		case .Absolute:
			addr := (u16(instr_bytes[2]) << 8) | u16(instr_bytes[1])
			if instr.opcode == .JMP || instr.opcode == .JSR {
				fmt.sbprintf(&logLine, "$%4X\t\t", arg)
			} else {
				if instr.readmem {
					fmt.sbprintf(&logLine, "$%4X = %2X\t\t", addr, arg)
				} else {
					fmt.sbprintf(&logLine, "$%4X = %2X\t\t", addr, cpu_read(cpu, arg))
				}
			}
		case .XIndexedAbsolute:
			base := (u16(instr_bytes[2]) << 8) | u16(instr_bytes[1])
			addr := u16(cpu.x) + base
			if instr.readmem {
				fmt.sbprintf(&logLine, "$%4X,X @ %4X = %2X\t\t", base, addr, arg)
			} else {
				fmt.sbprintf(&logLine, "$%4X,X @ %4X = %2X\t\t", base, addr, cpu_read(cpu, arg))
			}
		case .YIndexedAbsolute:
			base := (u16(instr_bytes[2]) << 8) | u16(instr_bytes[1])
			addr := u16(cpu.y) + base
			if instr.readmem {
				fmt.sbprintf(&logLine, "$%4X,Y @ %4X = %2X\t\t", base, addr, arg)
			} else {
				fmt.sbprintf(&logLine, "$%4X,Y @ %4X = %2X\t\t", base, addr, cpu_read(cpu, arg))
			}
		case .AbsoluteIndirect: 
			ptr := (u16(instr_bytes[2]) << 8) | u16(instr_bytes[1])
			fmt.sbprintf(&logLine, "($%4X) = %4X\t\t\t", ptr, arg)
		case .ZeroPage:
			addr := instr_bytes[1]
			if instr.readmem {
				fmt.sbprintf(&logLine, "$%2X = %2X\t\t", addr, arg)
			} else {
				fmt.sbprintf(&logLine, "$%2X = %2X\t\t", addr, cpu_read(cpu, arg))
			}
		case .XIndexedZeroPage:
			base := instr_bytes[1]
			addr := (cpu.x + base) & 0xff
			if instr.readmem {
				fmt.sbprintf(&logLine, "$%2X,X @ %2X = %2X\t\t\t", base, addr, arg)
			} else {
				fmt.sbprintf(&logLine, "$%2X,X @ %2X = %2X\t\t\t", base, addr, cpu_read(cpu, arg))
			}
		case .YIndexedZeroPage:
			base := instr_bytes[1]
			addr := (cpu.y + base) & 0xff 
			if instr.readmem {
				fmt.sbprintf(&logLine, "$%2X,Y @ %2X = %2X\t\t\t", base, addr, arg)
			} else {
				fmt.sbprintf(&logLine, "$%2X,Y @ %2X = %2X\t\t\t", base, addr, cpu_read(cpu, arg))
			}
		case .XIndexedZeroPageIndirect:
			base := instr_bytes[1]
			paddr := (cpu.x + base) & 0xff // address
			ptr := 	cpu_read_u16_zp(cpu, u16(paddr))
			
			if instr.readmem { 
				fmt.sbprintf(&logLine, "($%2X,X) @ %2X = %4X = %2X\t\t\t", base, paddr, ptr, arg)
			} else {
				fmt.sbprintf(&logLine, "($%2X,X) @ %2X = %4X = %2X\t\t\t", base, paddr, ptr, cpu_read(cpu, arg))
			}
		case .ZeroPageIndirectYIndexed:
			base := u16(instr_bytes[1])
			ptr := cpu_read_u16_zp(cpu, base)
			addr := ptr + u16(cpu.y) 
			if instr.readmem {
				fmt.sbprintf(&logLine, "($%2X),Y = %4X @ %4X = %2X\t\t\t", base, ptr, addr, arg)
			} else {
				fmt.sbprintf(&logLine, "($%2X),Y = %4X @ %4X = %2X\t\t\t", base, ptr, addr, cpu_read(cpu, arg))
			}
		case .Accumulator: 
			fmt.sbprintf(&logLine, "A\t\t\t")
		case .Implied:
			fmt.sbprintf(&logLine, " \t\t\t")
		case .Relative:
			fmt.sbprintf(&logLine, "$%4X\t\t", arg)
	}

	sb := transmute(u8)(cpu.status)
	fmt.sbprintf(&logLine, "A:%2X X:%2X Y:%2X P:%2X SP:%2X CYC:%d\n", cpu.a, cpu.x, cpu.y, sb, cpu.sp, cpu.clock)
	fmt.printf("%s", strings.to_string(logLine))
}

is_page_crossed :: proc(addr: u16, idx: u8) -> bool {
	return ((addr & 0xff) + u16(idx)) > 0xff
}

cpu_read_u16_zp :: proc(cpu: ^Cpu, addr: u16) -> u16 {
	low := u16(cpu_read(cpu, addr & 0xff))
	high := u16(cpu_read(cpu, (addr + 1) & 0xff))
	return (high << 8) | low
}

cpu_read_u16 :: proc(cpu: ^Cpu, addr: u16) -> u16 {
	low := u16(cpu_read(cpu, addr))
	high := u16(cpu_read(cpu, addr + 1))
	return (high << 8) | low
}

cpu_get_operand :: proc(cpu: ^Cpu, instr: ^Instruction) -> u16 {
	operand: u16;
	check_page_cross: bool 

	#partial switch instr.addrmode {
		case .Immediate, .ZeroPage:
			operand = u16(cpu_read(cpu, cpu.pc + 1))

		case .Absolute: 
			operand = cpu_read_u16(cpu, cpu.pc + 1)

		case .XIndexedAbsolute: 
			base := cpu_read_u16(cpu, cpu.pc + 1)
			check_page_cross = is_page_crossed(base, cpu.x)
			operand = u16(cpu.x) + base

		case .YIndexedAbsolute:
			base := cpu_read_u16(cpu, cpu.pc + 1)
			check_page_cross = is_page_crossed(base, cpu.y)
			operand = u16(cpu.y) + base

		case .XIndexedZeroPage:
			base := u16(cpu_read(cpu, cpu.pc + 1))
			idx := u16(cpu.x)
			operand = (idx + base) & 0xff

		case .YIndexedZeroPage: 
			base := u16(cpu_read(cpu, cpu.pc + 1))
			idx := u16(cpu.y)
			operand = (base + idx) & 0xff

		case .XIndexedZeroPageIndirect:
			paddr := u16(cpu_read(cpu, cpu.pc + 1) + cpu.x) & 0xff
			operand = cpu_read_u16_zp(cpu, paddr)

		case .ZeroPageIndirectYIndexed: 
			paddr := cpu_read(cpu, cpu.pc + 1)
			ptr := cpu_read_u16_zp(cpu, u16(paddr))
			check_page_cross = is_page_crossed(ptr, cpu.y) 
			operand = ptr + u16(cpu.y)

		case .Relative: 
			offset := i8(cpu_read(cpu, cpu.pc + 1))
			check_page_cross = (((cpu.pc + 2) & 0xff) + u16(i16(offset))) > 0xff
			operand = cpu.pc + u16(i16(offset)) + 2

		case .AbsoluteIndirect:
			p := cpu_read_u16(cpu, cpu.pc + 1)
			if p & 0xff != 0 {
				operand = (u16(cpu_read(cpu, p & 0xff00)) << 8) | u16(cpu_read(cpu, p))
			} else {
				operand = cpu_read_u16(cpu, p)
			}

		case .Accumulator:
			operand = u16(cpu.a)
	}	

	if instr.readmem {
		operand = u16(cpu_read(cpu, operand))
	}

	if instr.check_cross && !check_page_cross {
		instr.cycles -= CROSS
	}

	return operand;
}

cpu_execute :: proc(cpu: ^Cpu) {
	op := cpu_read(cpu, cpu.pc)
	instr := instructions[op]
	operand := cpu_get_operand(cpu, &instr)
	
	// instr_bytes: [3]byte

	// cpu_debug_ctx: CPUDebugContext
	// cpu_debug_ctx.cpu = cpu
	// cpu_debug_ctx.instr = instr

	// if instr.size == 1 {
	// 	cpu_debug_ctx.instr_bytes[0] = op
	// } else if instr.size == 2 {
	// 	cpu_debug_ctx.instr_bytes[0] = op
	// 	cpu_debug_ctx.instr_bytes[1] = cpu_read(cpu, cpu.pc + 1)
	// } else if instr.size == 3 {
	// 	cpu_debug_ctx.instr_bytes[0] = op
	// 	cpu_debug_ctx.instr_bytes[1] = cpu_read(cpu, cpu.pc + 1)
	// 	cpu_debug_ctx.instr_bytes[2] = cpu_read(cpu, cpu.pc + 2)
	// }

	// cpu_debug_ctx.arg = operand
	// cpu_log(cpu_debug_ctx)

	cpu.pc += u16(instr.size)

	#partial switch  instr.opcode {
		case .LDA: lda(cpu, u8(operand)) 
		case .LDX: ldx(cpu, u8(operand))
		case .LDY: ldy(cpu, u8(operand))
		case .STA: sta(cpu, operand)
		case .STX: stx(cpu, operand)
		case .STY: sty(cpu, operand)
		case .TAX: tax(cpu)
		case .TAY: tay(cpu)
		case .TSX: tsx(cpu)
		case .TXA: txa(cpu)
		case .TXS: txs(cpu)
		case .TYA: tya(cpu)
		case .PHA: pha(cpu)
		case .PHP: php(cpu)
		case .PLA: pla(cpu)
		case .PLP: plp(cpu)
		case .ASL: asl(cpu, instr.addrmode == .Accumulator, operand)
		case .LSR: lsr(cpu, instr.addrmode == .Accumulator, operand)
		case .ROL: rol(cpu, instr.addrmode == .Accumulator, operand)
		case .ROR: ror(cpu, instr.addrmode == .Accumulator, operand)
		case .AND: and(cpu, u8(operand))
		case .BIT: bit(cpu, u8(operand))
		case .EOR: eor(cpu, u8(operand))
		case .ORA: ora(cpu, u8(operand))
		case .ADC: adc(cpu, u8(operand))
		case .SBC: adc(cpu, ~u8(operand))
		case .CMP: cmp(cpu, u8(operand))
		case .CPX: cpx(cpu, u8(operand))
		case .CPY: cpy(cpu, u8(operand))
		case .DEC: dec(cpu, operand)
		case .DEX: dex(cpu)
		case .DEY: dey(cpu)
		case .INC: inc(cpu, operand)
		case .INX: inx(cpu)
		case .INY: iny(cpu)
		case .RTS: rts(cpu)
		case .RTI: rti(cpu)
		case .JSR: jsr(cpu, operand)
		case .JMP: jmp(cpu, operand)
		case .BCC: bcc(cpu, &instr, operand)
		case .BCS: bcs(cpu, &instr, operand)
		case .BEQ: beq(cpu, &instr, operand)
		case .BMI: bmi(cpu, &instr, operand)
		case .BNE: bne(cpu, &instr, operand)
		case .BPL: bpl(cpu, &instr, operand)
		case .BVC: bvc(cpu, &instr, operand)
		case .BVS: bvs(cpu, &instr, operand)
		case .CLC: clc(cpu)
		case .CLD: cld(cpu)
		case .CLI: cli(cpu)
		case .CLV: clv(cpu)
		case .SEC: sec(cpu)
		case .SED: sed(cpu)
		case .SEI: sei(cpu)
		case .LAX: lax(cpu, u8(operand))
		case .SAX: sax(cpu, operand)
		case .DCP: dcp(cpu, operand)
		case .ISB: isb(cpu, operand)
		case .SLO: slo(cpu, operand)
		case .RLA: rla(cpu, operand)
		case .SRE: sre(cpu, operand)
		case .RRA: rra(cpu, operand)
		case .NOP: 
	}

	cpu.clock += instr.cycles
}

cart_init :: proc(cart: ^Cartidage, _ines: ^ines.iNES) {
	cart.prg_rom = _ines.prg_rom
	cart.chr_rom = _ines.chr_rom
	cart.bank_count = ines.bank_count(_ines)
	cart.mapper = ines.mapper(_ines)
}

hex_view :: proc(b: []byte, n: int) {

	s := strings.builder_make()

	i := 0
	fmt.sbprintf(&s,"       ")
	for j := 0; j < n; j += 1 {
		fmt.sbprintf(&s, "%2X ", j)
	}

	fmt.sbprintf(&s,"\n       ")
	for j := 0; j < n; j += 1 {
		fmt.sbprintf(&s,"___")
	}

	fmt.sbprintf(&s,"\n\n")

	for i < len(b) {
		fmt.sbprintf(&s,"%4X:  ", i)
		
		for j := 0; j+i < len(b) && j < n; j += 1 {
			fmt.sbprintf(&s,"%2X ", b[j+i])
		}

		i += n
		fmt.sbprintf(&s,"\n")
	}

	fmt.printf("%s", strings.to_string(s))
}

draw_tile_monochrome :: proc(pattern_table: []byte, tile_idx: int) {
	rw := 4
	rh := 4

	tile_byte_index := 16*tile_idx
	tile_ix := 8 * rw * (tile_idx & 0xf)
	tile_iy := 8 * rh * ((tile_idx & 0xf0) >> 4)

	tile_bytes := pattern_table[tile_byte_index:tile_byte_index+16]

	for j := 0; j < len(tile_bytes); j += 1 {
		for i := 0; i < 8; i += 1 {
			fill := (tile_bytes[j] & (1 << uint(i))) != 0
			if fill {
				x := tile_ix + ((8-i) * rw)
				y := tile_iy + (j * rh)
				rl.DrawRectangleRec({f32(x), f32(y), f32(rw), f32(rh)}, rl.WHITE)
			}
		}
	}
}

main :: proc() {
	nes: NES
	cpu: Cpu
	ppu: PPU
	apu: APU

	cpu_init(&cpu)

	nes.cpu = &cpu
	cpu.nes = &nes

	W  :: 32 
	H  :: 32
	SX :: 10 
	SY :: 10

	rl.InitWindow(W*SX, H*SY, "6502 Snake")

	for !rl.WindowShouldClose() {

		cpu_execute(&cpu)

		if rl.IsKeyPressed(rl.KeyboardKey.UP) {
			last_pressed_button = 'w'
		} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
			last_pressed_button = 'a'
		} else if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
			last_pressed_button = 's'
		} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
			last_pressed_button = 'd'
		}
		
		rl.BeginDrawing()

		for y := 0; y < H; y += 1 {
			for x := 0; x < W; x += 1 {				
				pixel_addr := u16(0x0200 + (x + y*W))
				pixel := nes_read(&nes, pixel_addr)
				px := f32(x * SX)
				py := f32(y * SY)

				if pixel == 0 {
					rl.DrawRectangleRec({px, py, 10, 10}, rl.BLACK)
				} else if pixel == 1 {
					rl.DrawRectangleRec({px, py, 10, 10}, rl.BLUE)
				} else {
					rl.DrawRectangleRec({px, py, 10, 10}, rl.RED)
				} 
			}
		}

		rl.EndDrawing()

		time.sleep(10)
	}
}