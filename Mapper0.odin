package main

mapper0_cpu_map :: proc(bank_count: uint, addr: u16) -> u16 {
	mapped := (bank_count > 1) ? addr & 0x7FFF : addr & 0x3FFF
	return mapped
}

mapper0_ppu_map :: proc(addr: u16) -> u16 {
	mapped := addr & 0x0007
	return mapped
}