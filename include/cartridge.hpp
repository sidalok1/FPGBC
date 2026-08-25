#pragma once

#include <memory>
#include <cstdint>
#include <vector>
#include <array>
#include <iostream>
#include <fstream>
#include <filesystem>

const std::uint16_t CGB_FLAG_ADDR = 0x0143;
const std::uint16_t TITLE_LOW_ADDR = 0x0134;

class Cartridge {
protected:
	std::vector<std::uint8_t> ROM;
	std::vector<std::uint8_t> RAM;
	bool hasBattery;
public:
	std::filesystem::path rompath;
	virtual std::uint8_t read(std::uint16_t addr) = 0;
	virtual void write(std::uint16_t addr, std::uint8_t data) = 0;
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