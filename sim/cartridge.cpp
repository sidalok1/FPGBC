#include "cartridge.hpp"
#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <utility>

// namespace time = std::chrono;

class NoMBC : public Cartridge {
private:
	bool has_ram;
public:
	NoMBC (
		std::vector<std::uint8_t> ROMDATA, 
		bool has_ramm) : has_ram(has_ram) {
		ROM = ROMDATA;
		if ( has_ram ) {
			RAM = std::vector<std::uint8_t>(0x2000);
		}
		hasBattery = hasBattery;
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
	void save() override {
		if ( has_ram ) {
			std::filesystem::path savepath = rompath.replace_extension("sav");
			std::ofstream savefile(savepath);
			savefile.write(reinterpret_cast<const char*>(RAM.data()), RAM.capacity());
			savefile.close();
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
		std::vector<std::uint8_t> RAMBANKS, 
		bool has_battery = false ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		bank_reg_high = 0x00;
		bank_reg_low= 0x01;
		RAM_enable = false;
		banking_mode = simple;
		hasBattery = has_battery;
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

#pragma pack(push, 1)
typedef struct {
	std::uint32_t S;
	std::uint32_t M;
	std::uint32_t H;
	std::uint32_t DL;
	std::uint32_t DH;
} RTC_regs_t;
#pragma pack(pop)

class MBC3 : public Cartridge {
private:
	bool RAM_and_TIM_enable;
	bool is_latched;
	std::uint8_t ROM_bank;
	std::uint8_t RAM_bank;
	RTC_regs_t latched_regs;
	RTC_regs_t hidden_regs;
	void halt_timer() {
		last_halted = MBC3_clock::now();
		hidden_regs.DH |= (1 << 6);
	}
	void unhalt_timer() {
		last_update = MBC3_clock::now();
		hidden_regs.DH &= ~(1 << 6);
	}
	void set_carry() {
		hidden_regs.DH |= (1 << 7);
	}
	void set_day(uint16_t day) {
		hidden_regs.DL = day & 0xFF;
		hidden_regs.DH = (day >> 8) & 0xFF;
	}
	void add_to_days(uint8_t num) {
		uint16_t old_day = get_day();
		uint16_t new_day = old_day + num;
		if ( new_day > max_days ) {
			new_day -= max_days;
			set_carry();
		}
		set_day(new_day);
	}
	void add_to_hours(uint8_t num) {
		hidden_regs.H += num;
		if ( hidden_regs.H > 24 ) {
			hidden_regs.H -= 24;
			add_to_days(1);
		}
	}
	void add_to_minutes(uint8_t num) {
		hidden_regs.M += num;
		if ( hidden_regs.M > 60 ) {
			hidden_regs.M -= 60;
			add_to_hours(1);
		}
	}
	void add_to_seconds(uint8_t num) {
		hidden_regs.S += num;
		if ( hidden_regs.S > 60 ) {
			hidden_regs.S -= 60;
			add_to_minutes(1);
		}
	}
public:
	typedef std::chrono::steady_clock MBC3_clock;
	typedef std::chrono::time_point<MBC3_clock> MBC3_timepoint;
	typedef std::chrono::duration<int64_t> MBC3_duration;
	static constexpr auto s = std::chrono::seconds(1);
	static constexpr auto m = std::chrono::minutes(1);
	static constexpr auto h = std::chrono::hours(1);
	static constexpr auto d = std::chrono::hours(24);
	static constexpr uint16_t max_days = 0x01FF;
	MBC3_timepoint last_update;
	MBC3_timepoint last_halted;
	uint16_t get_day() const {
		return (hidden_regs.DH & 0xFF) | ((hidden_regs.DH & 0x01) << 8);
	}
	void update_time() {
		MBC3_timepoint new_update;
		if ( is_halted() ) {
			new_update = last_halted;
		}
		else {
			new_update = MBC3_clock::now();
		}
		auto elapsed_time = 
			std::chrono::duration_cast<MBC3_duration>(last_update - new_update);
		auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(elapsed_time % m);
		add_to_seconds(elapsed_seconds.count());
		auto elapsed_minutes = std::chrono::duration_cast<std::chrono::minutes>(elapsed_time % h);
		add_to_minutes(elapsed_minutes.count());
		auto elapsed_hours = std::chrono::duration_cast<std::chrono::hours>(elapsed_time % d);
		add_to_hours(elapsed_hours.count());
		auto elapsed_days = std::chrono::duration_cast<std::chrono::hours>(elapsed_time) / 24;
		add_to_days(elapsed_days.count());
		last_update = new_update;
	}
	bool is_halted() const {
		return (hidden_regs.DH & (1 << 6)) != 0;
	}
	MBC3 (
		std::vector<std::uint8_t> ROMBANKS, 
		std::vector<std::uint8_t> RAMBANKS,
		RTC_regs_t hidden,
		RTC_regs_t latched,
		bool hasBattery = false ) : 
		hidden_regs(hidden), latched_regs(latched) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		RAM_and_TIM_enable = false;
		ROM_bank = 0x01;
		RAM_bank = 0x00;
		is_latched = false;
		last_update = std::chrono::steady_clock().now();
		last_halted = last_update;
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
			if ( !RAM_and_TIM_enable ) {
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM or timer\n");
				return 0xFF;
			}
			else {
				std::uint16_t ramaddr = addr & 0x1FFF;
				switch (RAM_bank)
				{
				case 0x08:
					return latched_regs.S;
				case 0x09:
					return latched_regs.M;
				case 0x0A:
					return latched_regs.H;
				case 0x0B:
					return latched_regs.DL;
				case 0x0C:
					latched_regs.DH = (hidden_regs.DH & 0xFE) | (latched_regs.DH & 0x01);
					return latched_regs.DH;
				default:
					ramaddr |= RAM_bank << 13;
					break;
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
				RAM_and_TIM_enable = true;
			}
			else {
				RAM_and_TIM_enable = false;
			}
		}
		else if ( addr >= 0x2000 && addr <= 0x3FFF ) {
			std::uint8_t val = data & 0x7F;
			if ( val == 0 ) {
				val = 0x01;
			}
			ROM_bank = val;
		}
		else if ( addr >= 0x4000 && addr <= 0x5FFF ) {
			RAM_bank = data & 0xFF;
		}
		else if ( addr >= 0x6000 && addr <= 0x7FFF ) {
			bool was_latched = is_latched;
			is_latched = data & 0x01 == 0x01;
			if ( !was_latched && is_latched ) {
				update_time();
				latched_regs = hidden_regs;
			}
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_and_TIM_enable ) {
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM or timer\n");
			}
			else {
				std::uint16_t ramaddr = addr & 0x1FFF;
				bool currently_halted;
				switch (RAM_bank)
				{
				case 0x08:
					latched_regs.S = data;
					break;
				case 0x09:
					latched_regs.M = data;
					break;
				case 0x0A:
					latched_regs.H = data;
					break;
				case 0x0B:
					latched_regs.DL = data;
					break;
				case 0x0C:
					currently_halted = is_halted();
					if ( !currently_halted && data & (1 << 7) == 0 ) {
						halt_timer();
					}
					else if ( currently_halted && data & (1 << 7) != 0 ) {
						unhalt_timer();
					}
					latched_regs.DH = data;
					break;
				default:
					ramaddr |= RAM_bank << 13;
					break;
				}
				RAM[ramaddr % RAM.capacity()] = data;
			}
		}
		else {
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)\n", addr, data);
		}
	}
	~MBC3() override {
		SDL_Log("INFO: Shutting down MBC3\n");
		update_time();
		save();
	}
	void save() override {
		std::filesystem::path savepath = rompath.replace_extension("sav");
		SDL_Log("Savefile written at %s\n", savepath.c_str());
		std::ofstream savefile(savepath, std::ios::binary);
		savefile.write(reinterpret_cast<const char*>(RAM.data()), RAM.capacity());
		update_time();
		savefile.write(reinterpret_cast<const char*>(&hidden_regs), sizeof(RTC_regs_t));
		savefile.write(reinterpret_cast<const char*>(&latched_regs), sizeof(RTC_regs_t));
		std::int64_t t = std::chrono::duration_cast<std::chrono::seconds>
			(last_update.time_since_epoch()).count();
		savefile.write(reinterpret_cast<const char*>(&t), sizeof(t));
		savefile.close();
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
		std::vector<std::uint8_t> RAMBANKS,
		bool hasBattery = false ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		ROM_bank = 0x0001;
		RAM_bank = 0;
		RAM_enable = false;
		hasBattery = hasBattery;
		
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

bool mbc_has_battery(uint8_t val) {
	switch (val)
	{
	case 0x03:
	case 0x06:
	case 0x09:
	case 0x0D:
	case 0x0F:
	case 0x10:
	case 0x13:
	case 0x1B:
	case 0x1E:
	case 0x22:
	case 0xFF:
		return true;
	default:
		return false;
	}
}

std::unique_ptr<Cartridge> get_cartridge_from_romfile(std::filesystem::path ROMFILE) {
	std::ifstream f(ROMFILE, std::ios::binary);
	std::array<std::uint8_t, 0x50> header;
	f.seekg(0x100);
	f.read(reinterpret_cast<char*>(header.data()), 0x50);
	f.seekg(0);
	const char* game_title = reinterpret_cast<const char*>(&header[TITLE_LOW_ADDR-0x100]);
	std::string title(game_title, 11);
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
	std::vector<std::uint8_t> romdata(romsize);
	std::vector<std::uint8_t> ramdata(ramsize);

	RTC_regs_t hidden, latched;
	std::int64_t current_time = std::chrono::steady_clock::now().time_since_epoch().count();
	std::int64_t timestamp;

	std::filesystem::path savepath(ROMFILE);
	savepath.replace_extension("sav");
	if ( std::filesystem::exists(savepath) ) {
		std::ifstream savefile(savepath, std::ios::binary | std::ios::ate);
		int filesize = savefile.tellg();
		savefile.seekg(0);
		savefile.read(reinterpret_cast<char*>(ramdata.data()), ramsize);
		if ( filesize > savefile.tellg() ) {
			savefile.read(reinterpret_cast<char*>(&hidden), sizeof(RTC_regs_t));
			savefile.read(reinterpret_cast<char*>(&latched), sizeof(RTC_regs_t));
			int remaining_bytes = filesize - savefile.tellg();
			if ( remaining_bytes == 8 ) {
				savefile.read(reinterpret_cast<char*>(&timestamp), 8);
			}
			else if ( remaining_bytes == 4 ) {
				std::int32_t short_timestamp;
				savefile.read(reinterpret_cast<char*>(&short_timestamp), 4);
				timestamp = short_timestamp;
			}
			else {
				SDL_Log("Malformed save file with RTC data (%d bytes remaining)\n", remaining_bytes);
				timestamp = current_time;
			}
			if ( timestamp > current_time ) {
				timestamp = current_time;
			}
		}
	}
	bool has_battery = mbc_has_battery(header[0x47]);

	std::unique_ptr<Cartridge> cart;
	Cartridge* not_unique;
	MBC3* mbc;
	switch (header[0x47]) {
	case 0x00:
	case 0x08:
	case 0x09:
		SDL_Log("No MBC: $%X\n", header[0x47]);
		romdata = std::vector<std::uint8_t>(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		not_unique = static_cast<Cartridge*>(new NoMBC(romdata, ramsize != 0));
		break;
	case 0x01:
	case 0x02:
	case 0x03:
		SDL_Log("MBC1: $%X\n", header[0x47]);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		not_unique = static_cast<Cartridge*>(new MBC1(romdata, ramdata, has_battery));
		SDL_Log("Generated ROM size: %d\n", romdata.capacity());
		SDL_Log("Generated RAM size: %d\n", ramdata.capacity());
		break;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		SDL_Log("MBC3: $%X\n", header[0x47]);
		SDL_Log("WARNING: MBC3 supports timing functionality which is not fully tested\n");
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		mbc = (new MBC3(romdata, ramdata, hidden, latched, has_battery));
		mbc->last_halted = std::chrono::time_point<MBC3::MBC3_clock>(std::chrono::seconds(timestamp));
		mbc->last_update = mbc->last_halted;
		mbc->update_time();
		not_unique = static_cast<Cartridge*>(mbc);
		SDL_Log("Generated ROM size: %d\n", romdata.capacity());
		SDL_Log("Generated RAM size: %d\n", ramdata.capacity());
		break;
	case 0x19:
	case 0x1A:
	case 0x1B:
		SDL_Log("MBC5: $%X\n", header[0x47]);
		romdata = std::vector<std::uint8_t>(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		ramdata = std::vector<std::uint8_t>(ramsize);
		not_unique = static_cast<Cartridge*>(new MBC5(romdata, ramdata, has_battery));
		SDL_Log("Generated ROM size: %d\n", romdata.capacity());
		SDL_Log("Generated RAM size: %d\n", ramdata.capacity());
		break;
	default:
		SDL_Log("ERROR: That MBC is not yet implemented: %x\n", header[0x47]);
		f.close();
		return nullptr;
	}
	cart = std::unique_ptr<Cartridge>(not_unique);
	cart->rompath = ROMFILE;
	return cart;
}