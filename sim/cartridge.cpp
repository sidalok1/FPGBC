#include "cartridge.hpp"
#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <string>
// #include <mdspan>

class NoMBC : public Cartridge {
private:
	bool has_ram;
public:
	NoMBC (std::vector<std::uint8_t> ROMDATA, bool has_ram) : has_ram(has_ram) {
		ROM = ROMDATA;
		if ( has_ram ) {
			RAM = std::vector<std::uint8_t>(0x2000);
		}
	}
	std::uint8_t read(std::uint16_t addr) override {
		if ( addr >= 0x0000 && addr <= 0x7FFF ) {
			return ROM[addr];
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if (!has_ram) {
				SDL_Log("WARNING: Attempt to read RAM on (no)MBC without RAM at address %x\n", addr);
				return 0xFF;
			}
			else {
				return RAM[addr - 0xA000];
			}
		}
		else {
			SDL_Log("WARNING: Attempt to read from invalid address on cartridge with no MBC: %x\n", addr);
			return 0xFF;
		}
	}
	void write(std::uint16_t addr, uint8_t data) override {
		if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if (!has_ram) {
				SDL_Log("WARNING: Attempt to write RAM on (no)MBC without RAM at address %x\n", addr);
			}
			else {
				RAM[addr - 0xA000] = data;
			}
		}
		else {
			SDL_Log("WARNING: Attempt to write to invalid address on cartridge with no MBC: %x\n", addr);
		}
	}
};

class MBC1 : public Cartridge {
	static const std::uint8_t simple = 0;
	static const std::uint8_t advanced = 1;
private:
	std::uint8_t banking_mode;
	bool RAM_enable;
	std::uint8_t bank_reg_low;
	std::uint8_t bank_reg_high;
public:
	MBC1 (
		std::vector<std::uint8_t> ROMBANKS, 
		std::vector<std::uint8_t> RAMBANKS ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		bank_reg_high = 0x00;
		bank_reg_low= 0x01;
		RAM_enable = false;
		banking_mode = simple;
		
	}
	std::uint8_t read(std::uint16_t addr) override {
		if ( addr >= 0x0000 && addr <= 0x3FFF ) {
			std::uint32_t romaddr = addr & 0x3FFF;
			if ( banking_mode == advanced ) {
				romaddr |= bank_reg_high << 19;
			}
			return ROM[romaddr % ROM.capacity()];
		}
		else if ( addr >= 0x4000 && addr <= 0x7FFF ) {
			std::uint8_t bank = bank_reg_low | (bank_reg_high << 5);
			std::uint32_t romaddr = (addr & 0x3FFF) | 
									(bank << 14);
			return ROM[romaddr % ROM.capacity()];
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_enable ) {
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM\n");
				return 0xFF;
			}
			else {
				std::uint16_t ramaddr = addr & 0x1FFF;
				if ( banking_mode == advanced ) {
					ramaddr |= bank_reg_high << 13;
				}
				return RAM[ramaddr % RAM.capacity()];
			}

		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory access at: 0x%X\n", addr);
			return 0xFF;
		}
	}
	void write(std::uint16_t addr, std::uint8_t data) override {
		if ( addr >= 0x0000 && addr <= 0x1FFF ) {
			if ( (data & 0x0F) == 0x0A ) {
				RAM_enable = true;
			}
			else {
				RAM_enable = false;
			}
		}
		else if ( addr >= 0x2000 && addr <= 0x3FFF ) {
			std::uint8_t val = data & 0x1F;
			if ( val == 0 ) {
				val = 0x01;
			}
			bank_reg_low = val;
		}
		else if ( addr >= 0x4000 && addr <= 0x5FFF ) {
			bank_reg_high = data & 0x03;
		}
		else if ( addr >= 0x6000 && addr <= 0x7FFF ) {
			banking_mode = data & 0x01;
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_enable ) {
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM\n");
			}
			else {
				std::uint16_t ramaddr = addr & 0x1FFF;
				if ( banking_mode == advanced ) {
					ramaddr |= bank_reg_high << 13;
				}
				RAM[ramaddr % RAM.capacity()] = data;
			}
		}
		else {
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)\n", addr, data);
		}
	}
};

class MBC5 : public Cartridge {
private:
	bool RAM_enable;
	std::uint16_t ROM_bank;
	std::uint8_t RAM_bank;
public:
	MBC5 (
		std::vector<std::uint8_t> ROMBANKS, 
		std::vector<std::uint8_t> RAMBANKS ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		ROM_bank = 0x0001;
		RAM_bank = 0;
		RAM_enable = false;
		
	}

	std::uint8_t read(std::uint16_t addr) override {
		if ( addr >= 0x0000 && addr <= 0x3FFF ) {
			std::uint32_t romaddr = addr & 0x3FFF;
			return ROM[romaddr % ROM.capacity()];
		}
		else if ( addr >= 0x4000 && addr <= 0x7FFF ) {
			std::uint32_t romaddr = (addr & 0x3FFF) | 
									(ROM_bank << 14);
			return ROM[romaddr % ROM.capacity()];
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_enable ) {
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM\n");
				return 0xFF;
			}
			else {
				std::uint16_t ramaddr = (addr & 0x1FFF) | (RAM_bank << 13);
				return RAM[ramaddr % RAM.capacity()];
			}
		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory access at: 0x%X\n", addr);
			return 0xFF;
		}
	}
	void write(std::uint16_t addr, std::uint8_t data) override {
		if ( addr >= 0x0000 && addr <= 0x1FFF ) {
			// if ( (data & 0x0F) == 0x0A ) {
			if ( data == 0x0A ) {
				RAM_enable = true;
			}
			else {
				RAM_enable = false;
			}
		}
		else if ( addr >= 0x2000 && addr <= 0x2FFF ) {
			std::uint8_t val = data & 0xFF;
			ROM_bank = (ROM_bank & 0xFF00) | val;
		}
		else if ( addr <= 0x3000 && addr <= 0x3FFF ) {
			std::uint8_t val = data & 0x01;
			ROM_bank = (ROM_bank & 0x00FF) | (val << 8);
		}
		else if ( addr >= 0x4000 && addr <= 0x5FFF ) {
			RAM_bank = data & 0x0F;
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_enable ) {
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM\n");
			}
			else {
				std::uint16_t ramaddr = (addr & 0x1FFF) | (RAM_bank << 13);
				RAM[ramaddr % RAM.capacity()] = data;
			}
		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)\n", addr, data);
		}
	}
};

std::unique_ptr<Cartridge> get_cartridge_from_romfile(const char* ROMFILE) {
	std::ifstream f(ROMFILE, std::ios::binary);
	std::array<std::uint8_t, 0x50> header;
	f.seekg(0x100);
	f.read(reinterpret_cast<char*>(header.data()), 0x50);
	f.seekg(0);
	const char* game_title = reinterpret_cast<const char*>(&header[TITLE_LOW_ADDR-0x100]);
	std::string title(game_title, 11);
	// std::cout << " Loading: " << title << std::endl;
	SDL_Log("Loading: %s\n", title.c_str());
	std::uint32_t romsize;
	if ( header[0x48] >= 0x00 && header[0x48] <= 0x08 ) {
		romsize = 0x8000 * (1 << header[0x48]);
		SDL_Log("ROM size: %dKiB (val = 0x%0X)\n", 32*(1<<header[0x48]), header[0x48]);
	}
	else {
		SDL_Log("ERROR: Invalid ROM size value: 0x%X\n", header[0x48]);
		return nullptr;
	}
	std::uint32_t ramsize;
	switch (header[0x49]) {
		case 0x00:
			ramsize = 0;
			SDL_Log("RAM size: none\n");
			break;
		case 0x02:
			ramsize = 0x00002000;
			SDL_Log("RAM size: 8KiB\n");
			break;
		case 0x03:
			ramsize = 0x00008000;
			SDL_Log("RAM size: 32KiB\n");
			break;
		case 0x04:
			ramsize = 0x00020000;
			SDL_Log("RAM size: 128KiB\n");
			break;
		case 0x05:
			ramsize = 0x00010000;
			SDL_Log("RAM size: 64KiB\n");
			break;
		default:
			SDL_Log("ERROR: Invalid RAM size value: %x\n", header[0x49]);
			return nullptr;
	}
	std::vector<std::uint8_t> romdata;
	std::vector<std::uint8_t> ramdata;
	std::unique_ptr<Cartridge> cart;
	switch (header[0x47]) {
	case 0x00:
	case 0x08:
	case 0x09:
		SDL_Log("No MBC: $%X\n", header[0x47]);
		romdata = std::vector<std::uint8_t>(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		cart = std::unique_ptr<Cartridge>(static_cast<Cartridge*>(new NoMBC(romdata, ramsize != 0)));
		return cart;
	case 0x01:
	case 0x02:
	case 0x03:
		SDL_Log("MBC1: $%X\n", header[0x47]);
		romdata = std::vector<std::uint8_t>(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		ramdata = std::vector<std::uint8_t>(ramsize);
		cart = std::unique_ptr<Cartridge>(static_cast<Cartridge*>(new MBC1(romdata, ramdata)));
		SDL_Log("Generated ROM size: %d\n", romdata.capacity());
		SDL_Log("Generated RAM size: %d\n", ramdata.capacity());
		return cart;
	case 0x19:
	case 0x1A:
	case 0x1B:
		SDL_Log("MBC5: $%X\n", header[0x47]);
		romdata = std::vector<std::uint8_t>(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		ramdata = std::vector<std::uint8_t>(ramsize);
		cart = std::unique_ptr<Cartridge>(static_cast<Cartridge*>(new MBC5(romdata, ramdata)));
		SDL_Log("Generated ROM size: %d\n", romdata.capacity());
		SDL_Log("Generated RAM size: %d\n", ramdata.capacity());
		return cart;
	default:
		SDL_Log("ERROR: That MBC is not yet implemented: %x\n", header[0x47]);
		f.close();
		return nullptr;
	}
}