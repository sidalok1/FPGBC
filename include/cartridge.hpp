#pragma once

#include <memory>
#include <cstdint>
#include <vector>
#include <fstream>
#include <filesystem>


using memdata_t = std::uint8_t;
using memaddr_t = std::uint16_t;
using memory_t = std::vector<memdata_t>;
const memaddr_t CGB_FLAG_ADDR = 0x0143;
const memaddr_t TITLE_LOW_ADDR = 0x0134;

class Cartridge {
protected:
	memory_t ROM;
	memory_t RAM;
	bool hasBattery;
public:
	std::filesystem::path rompath;
	virtual memdata_t read(memaddr_t addr) = 0;
	virtual void write(memaddr_t addr, memdata_t data) = 0;
	virtual void save() {
		std::filesystem::path savepath = rompath.replace_extension("sav");
		std::ofstream savefile(savepath);
		savefile.write(reinterpret_cast<const char*>(RAM.data()), RAM.capacity());
		savefile.close();
	}
	virtual ~Cartridge() {
		if ( hasBattery ) {
			save();
		}
	}
};

std::unique_ptr<Cartridge> get_cartridge_from_romfile(std::filesystem::path ROMFILE);