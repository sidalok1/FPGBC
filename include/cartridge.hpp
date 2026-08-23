#pragma once

#include <memory>
#include <cstdint>
#include <vector>
#include <array>
#include <iostream>
#include <fstream>

const std::uint16_t CGB_FLAG_ADDR = 0x0143;
const std::uint16_t TITLE_LOW_ADDR = 0x0134;

class Cartridge {
protected:
	std::vector<std::uint8_t> ROM;
	std::vector<std::uint8_t> RAM;
public:
	virtual std::uint8_t read(std::uint16_t addr) = 0;
	virtual void write(std::uint16_t addr, std::uint8_t data) = 0;
};

std::unique_ptr<Cartridge> get_cartridge_from_romfile(const char* ROMFILE);