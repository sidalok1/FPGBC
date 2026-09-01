#include "cartridge.hpp"
#include "bitops.hpp"
#include "doctest.h"
#include <bitset>
#include <SDL3/SDL.h>
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <utility>
#include <thread>

class NoMBC : public Cartridge {
private:
	bool has_ram;
public:
	NoMBC (
		memory_t ROMDATA, 
		bool has_ramm) : has_ram(has_ram) {
		ROM = ROMDATA;
		if ( has_ram ) {
			RAM = memory_t(0x2000);
		}
		hasBattery = hasBattery;
	}
	memdata_t read(memaddr_t addr) override {
		if ( addr >= 0x0000 && addr <= 0x7FFF ) {
			return ROM[addr];
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if (!has_ram) {
				SDL_Log("WARNING: Attempt to read RAM on (no)MBC without RAM at address %x", addr);
				return 0xFF;
			}
			else {
				return RAM[addr - 0xA000];
			}
		}
		else {
			SDL_Log("WARNING: Attempt to read from invalid address on cartridge with no MBC: %x", addr);
			return 0xFF;
		}
	}
	void write(memaddr_t addr, memdata_t data) override {
		if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if (!has_ram) {
				SDL_Log("WARNING: Attempt to write RAM on (no)MBC without RAM at address %x", addr);
			}
			else {
				RAM[addr - 0xA000] = data;
			}
		}
		else {
			SDL_Log("WARNING: Attempt to write to invalid address on cartridge with no MBC: %x", addr);
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
		memory_t ROMBANKS, 
		memory_t RAMBANKS, 
		bool has_battery = false ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		bank_reg_high = 0x00;
		bank_reg_low= 0x01;
		RAM_enable = false;
		banking_mode = simple;
		hasBattery = has_battery;
	}
	memdata_t read(memaddr_t addr) override {
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
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM");
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
			SDL_Log("WARNING: Invalid cartridge memory access at: 0x%X", addr);
			return 0xFF;
		}
	}
	void write(memaddr_t addr, memdata_t data) override {
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
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM");
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
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)", addr, data);
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
#pragma pack(push, 1)
typedef struct {
	RTC_regs_t hidden;
	RTC_regs_t latched;
	std::int64_t timestamp;
} RTC_data_t;
#pragma pack(pop)

RTC_data_t load_rtc_from_stream(std::ifstream& f) {
	auto pos = f.tellg();
	f.seekg(0, f.end);
	int size = f.tellg() - pos;
	f.seekg(pos);
	RTC_data_t data;
	f.read(reinterpret_cast<char*>(&data), sizeof(RTC_data_t));
	return data;
} 

class MBC3 : public Cartridge {
private:
	bool RAM_and_TIM_enable;
	bool is_latched;
	std::uint8_t ROM_bank;
	std::uint8_t RAM_bank;
	RTC_regs_t latched_regs;
	RTC_regs_t hidden_regs;
	bool is_halted() const {
		return bitops::getbit(hidden_regs.DH, 6);
	}
	void set_halted() {
		hidden_regs.DH = bitops::setbit(hidden_regs.DH, 6);
	}
	void clear_halted() {
		hidden_regs.DH = bitops::clrbit(hidden_regs.DH, 6);
	}
	bool has_carried() const {
		return bitops::getbit(hidden_regs.DH, 7);
	}
	void set_carried() {
		hidden_regs.DH = bitops::setbit(hidden_regs.DH, 7);
	}
	void clear_carried() {
		hidden_regs.DH = bitops::clrbit(hidden_regs.DH, 7);
	}
	void set_day(std::uint16_t day) {
		hidden_regs.DL = day & 0xFF;
		hidden_regs.DH = bitops::clrbit(hidden_regs.DH, 0);
		hidden_regs.DH |= bitops::getbit(day, 8);
	}
	void add_to_days(std::uint8_t num) {
		std::uint16_t old_day = get_day();
		std::uint16_t new_day = old_day + num;
		if ( new_day >= max_days ) {
			new_day -= max_days;
			set_carried();
		}
		set_day(new_day);
	}
	void add_to_hours(std::uint8_t num) {
		hidden_regs.H += num;
		if ( hidden_regs.H >= 24 ) {
			hidden_regs.H -= 24;
			add_to_days(1);
		}
	}
	void add_to_minutes(std::uint8_t num) {
		hidden_regs.M += num;
		if ( hidden_regs.M >= 60 ) {
			hidden_regs.M -= 60;
			add_to_hours(1);
		}
	}
	void add_to_seconds(std::uint8_t num) {
		hidden_regs.S += num;
		if ( hidden_regs.S >= 60 ) {
			hidden_regs.S -= 60;
			add_to_minutes(1);
		}
	}
public:
	using MBC3_clock = std::chrono::system_clock;
	using MBC3_duration = std::chrono::seconds;
	using MBC3_timepoint =  std::chrono::time_point<MBC3_clock, MBC3_duration>;
	static constexpr int s = 1;
	static constexpr int m = s * 60;
	static constexpr int h = m * 60;
	static constexpr int d = h * 24;
	static constexpr std::uint16_t max_days = 0x0200;
	static constexpr std::uint8_t 
		RTC_S = 0x08, RTC_M = 0x09, RTC_H = 0x0A, RTC_DL = 0x0B, RTC_DH = 0x0C;
	MBC3_timepoint last_update;
	static MBC3_timepoint get_time() {
		return std::chrono::time_point_cast<MBC3_duration>(MBC3_clock::now());
	}
	std::uint16_t get_day() const {
		return (hidden_regs.DL & 0xFF) | ((hidden_regs.DH & 0b1) << 8);
	}
	std::uint16_t get_latched_day() const {
		return (latched_regs.DL & 0xFF) | ((latched_regs.DH & 0b1) << 8);
	}
	void update_time() {
		MBC3_timepoint new_update = get_time();
		if ( !is_halted() ) {
			int elapsed_time = std::chrono::duration_cast<MBC3_duration>(new_update - last_update).count();
			int elapsed_seconds = elapsed_time % m;
			elapsed_time -= elapsed_seconds;
			add_to_seconds(elapsed_seconds / s);
			int elapsed_minutes = elapsed_time % h;
			elapsed_time -= elapsed_minutes;
			add_to_minutes(elapsed_minutes / m);
			int elapsed_hours = elapsed_time % d;
			elapsed_time -= elapsed_hours;
			add_to_hours(elapsed_hours / h);
			int elapsed_days = elapsed_time;
			add_to_days(elapsed_days / d);
		}
		last_update = new_update;
	}
	MBC3 (
		memory_t ROMBANKS, 
		memory_t RAMBANKS,
		RTC_data_t regs,
		bool hasBattery = false ) : 
		hidden_regs(regs.hidden), latched_regs(regs.latched) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		RAM_and_TIM_enable = true;
		ROM_bank = 0x01;
		RAM_bank = 0x00;
		is_latched = false;
		auto timestamp = MBC3_timepoint(std::chrono::seconds(regs.timestamp));
		auto current_time = get_time();
		SDL_Log("Timestamp passed to MBC constructor is %d", regs.timestamp);
		if ( regs.timestamp <= 0 || timestamp > current_time ) {
			last_update = current_time;
		}
		else {
			last_update = timestamp;
		}
	}
	memdata_t read(memaddr_t addr) override {
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
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM or timer");
				return 0xFF;
			}
			else {
				std::uint16_t ramaddr = addr & 0x1FFF;
				switch (RAM_bank)
				{
				case RTC_S:
					return latched_regs.S;
				case RTC_M:
					return latched_regs.M;
				case RTC_H:
					return latched_regs.H;
				case RTC_DL:
					return latched_regs.DL;
				case RTC_DH:
					return latched_regs.DH;
				default:
					ramaddr |= RAM_bank << 13;
					return RAM[ramaddr % RAM.capacity()];
					break;
				}
			}

		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory access at: 0x%X", addr);
			return 0xFF;
		}
	}
	void write(memaddr_t addr, memdata_t data) override {
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
			is_latched = (data & 0x01) == 0x01;
			if ( !was_latched && is_latched ) {
				update_time();
				latched_regs = hidden_regs;
			}
		}
		else if ( addr >= 0xA000 && addr <= 0xBFFF ) {
			if ( !RAM_and_TIM_enable ) {
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM or timer");
			}
			else {
				update_time();
				std::uint16_t ramaddr = addr & 0x1FFF;
				// according to pandocs, the halt flag is supposed to be set before writing
				// to the RTC registers. 
				// not really sure how that's supposed to work with writing to the halt flag
				// and the carry flag.
				// Also not entirely sure if writes are supposed to affect hidden regs or
				// latch regs, so I'm having them affect both
				switch (RAM_bank)
				{
				case RTC_S:
					hidden_regs.S = data;
					latched_regs.S = data;
					break;
				case RTC_M:
					hidden_regs.M = data;
					latched_regs.M = data;
					break;
				case RTC_H:
					hidden_regs.H = data;
					latched_regs.H = data;
					break;
				case RTC_DL:
					hidden_regs.DL = data;
					latched_regs.DL = data;
					break;
				case RTC_DH:
					hidden_regs.DH = data;
					latched_regs.DH = data;
					break;
				default:
					ramaddr |= RAM_bank << 13;
					RAM[ramaddr % RAM.capacity()] = data;
					break;
				}
			}
		}
		else {
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)", addr, data);
		}
	}
	~MBC3() override {
		SDL_Log("INFO: Shutting down MBC3");
		// update_time();
		save();
	}
	void save() override {
		std::filesystem::path savepath = rompath.replace_extension("sav");
		SDL_Log("Savefile written at %s", savepath.c_str());
		std::ofstream savefile(savepath, std::ios::binary);
		savefile.write(reinterpret_cast<const char*>(RAM.data()), RAM.capacity());
		update_time();
		savefile.write(reinterpret_cast<const char*>(&hidden_regs), sizeof(RTC_regs_t));
		savefile.write(reinterpret_cast<const char*>(&latched_regs), sizeof(RTC_regs_t));
		std::int64_t t = 
			(std::chrono::duration_cast<std::chrono::seconds>(last_update.time_since_epoch())).count();
		SDL_Log("Logging timestamp as: 0x%X", t);
		savefile.write(reinterpret_cast<const char*>(&t), sizeof(t));
		savefile.close();
	}
};


// Constants and functions for testing MBC3
constexpr std::array<std::uint8_t, 5> RTC_REGS = {
	MBC3::RTC_S, MBC3::RTC_M, MBC3::RTC_H, 
	MBC3::RTC_DL, MBC3::RTC_DH
};
constexpr std::uint8_t RTC_HALTBIT = 0b01000000;
constexpr std::uint8_t RTC_CRRYBIT = 0b10000000;
std::uint8_t get_reg(MBC3* uut, std::uint8_t regnum) {
	CHECK(regnum <= 0x0C);
	CHECK(regnum >= 0x08);
	uut->write(0x4000, regnum);
	return uut->read(0xA000);
}
void set_reg(MBC3* uut, std::uint8_t regnum, std::uint8_t data) {
	CHECK(regnum <= 0x0C);
	CHECK(regnum >= 0x08);
	uut->write(0x4000, regnum);
	uut->write(0xA000, data);
}
void set_rtc_regs(MBC3* uut, RTC_regs_t data) {
	set_reg(uut, MBC3::RTC_S, data.S);
	set_reg(uut, MBC3::RTC_M, data.M);
	set_reg(uut, MBC3::RTC_H, data.H);
	set_reg(uut, MBC3::RTC_DL, data.DL);
	set_reg(uut, MBC3::RTC_DH, data.DH);
}
void clear_rtc_regs(MBC3* uut) {
	set_rtc_regs(uut, {0, 0, 0, 0, 0});
}
void latch_rtc_regs(MBC3* uut) {
	uut->update_time();
	uut->write(0x6000, 0x01);
	uut->write(0x6000, 0x00);
	uut->write(0x6000, 0x01);
}
void test_rtc_regs(MBC3* uut, RTC_regs_t correct) {
	CHECK(get_reg(uut, MBC3::RTC_S) == correct.S);
	CHECK(get_reg(uut, MBC3::RTC_M) == correct.M);
	CHECK(get_reg(uut, MBC3::RTC_H) == correct.H);
	CHECK(get_reg(uut, MBC3::RTC_DL) == correct.DL);
	CHECK(get_reg(uut, MBC3::RTC_DH) == correct.DH);
}
std::uint8_t halt_rtc(MBC3* uut) {
	uut->write(0x4000, MBC3::RTC_DH);
	std::uint8_t dh = uut->read(0xA000);
	dh |= RTC_HALTBIT;
	uut->write(0xA000, dh);
	return dh;
}
std::uint8_t unhalt_rtc(MBC3* uut) {
	uut->write(0x4000, MBC3::RTC_DH);
	std::uint8_t dh = uut->read(0xA000);
	dh &= ~RTC_HALTBIT;
	uut->write(0xA000, dh);
	return dh;
}
TEST_CASE("MBC3 tests") {
	memory_t rom(0);
	memory_t ram(0);
	std::filesystem::path tmp("./_out/mbc3.sav");
	std::unique_ptr<MBC3> uut1(new MBC3(rom, ram, {0}, true));
	uut1->rompath = tmp;
	SDL_Log("Clearing RTC registers");
	clear_rtc_regs(uut1.get());
	SDL_Log("Testing cleared registers");
	test_rtc_regs(uut1.get(), {0, 0, 0, 0, 0});
	SUBCASE("Basic latching and time increment") {
		// Wait one second
		SDL_Log("Wait one second");
		std::this_thread::sleep_for(std::chrono::seconds(1));
		// Update time should only update hidden registers,
		// not the latched registers read by reads
		uut1->update_time();
		SDL_Log("Ensuring latched registers have not been changed by update_time()");
		test_rtc_regs(uut1.get(), {0, 0, 0, 0, 0});
		latch_rtc_regs(uut1.get());
		SDL_Log("Ensuring the correct values have been latched");
		test_rtc_regs(uut1.get(), {1, 0, 0, 0, 0});
		SDL_Log("Latched values should not have changed yet");
		test_rtc_regs(uut1.get(), {1, 0, 0, 0, 0});
	}
	SUBCASE("Basic halting") {
		std::uint8_t dh;
		// Sleep a total of two seconds, one of which is while halted
		SUBCASE("Read when halted") {
			// Wait one second not halted, and then two second halted
			SDL_Log("Waiting one second while not halted");
			std::this_thread::sleep_for(std::chrono::seconds(1));
			SDL_Log("Halting");
			dh = halt_rtc(uut1.get());
			std::this_thread::sleep_for(std::chrono::seconds(1));
			// Latching the halted regs should only latch the last 
			// unhalted time
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, dh});
			std::this_thread::sleep_for(std::chrono::seconds(1));
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, dh});
		}
		SUBCASE("Read when unhalted") {
			// Wait one second halted, end then two seconds not halted
			dh = halt_rtc(uut1.get());
			std::this_thread::sleep_for(std::chrono::seconds(1));
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {0, 0, 0, 0, dh});
			dh = unhalt_rtc(uut1.get());
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {0, 0, 0, 0, dh});
			std::this_thread::sleep_for(std::chrono::seconds(1));
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, dh});
		}
		SUBCASE("Halting when halted") {
			// No change should be observed if halted while already halted
			std::this_thread::sleep_for(std::chrono::seconds(1));
			dh = halt_rtc(uut1.get());
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, dh});
			std::this_thread::sleep_for(std::chrono::seconds(1));
			// Not saving new value of dh, since it should be same as old
			halt_rtc(uut1.get());
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, dh});
		}
		SUBCASE("Unhalting when unhalted") {
			std::this_thread::sleep_for(std::chrono::seconds(1));
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {1, 0, 0, 0, 0});
			std::this_thread::sleep_for(std::chrono::seconds(1));
			unhalt_rtc(uut1.get());
			latch_rtc_regs(uut1.get());
			test_rtc_regs(uut1.get(), {2, 0, 0, 0, 0});
		}
	}
	SUBCASE("Saving data") {
		auto should_halt = GENERATE(false, true);
		std::uint8_t dh;
		std::uint8_t hidden_s;
		if (should_halt) {
			halt_rtc(uut1.get());
			dh = RTC_HALTBIT;
			hidden_s = 0;
		}
		else {
			dh = 0;
			hidden_s = 1;
		}
		MBC3::MBC3_timepoint t1 = MBC3::get_time();
		std::this_thread::sleep_for(std::chrono::seconds(1));
		std::filesystem::remove(tmp);
		uut1->save();
		CHECK(std::filesystem::exists(tmp));
		std::ifstream f(tmp, std::ios::binary);
		RTC_data_t rtc_data = load_rtc_from_stream(f);
		SUBCASE("Basic save") {
			std::vector<std::uint32_t> correct_h = {hidden_s, 0, 0, 0, dh};
			std::vector<std::uint32_t> correct_l = {0, 0, 0, 0, dh};
			auto [h, l, saved_t] = rtc_data;
			MBC3::MBC3_timepoint t2 = MBC3::MBC3_timepoint(std::chrono::seconds(saved_t));
			int duration = std::chrono::duration_cast<MBC3::MBC3_duration>(t2 - t1).count();
			CHECK(duration == 1);
			auto hpointer = reinterpret_cast<std::uint32_t*>(&h);
			auto lpointer = reinterpret_cast<std::uint32_t*>(&l);
			std::span<std::uint32_t, 5> saved_h(hpointer, 5);
			std::span<std::uint32_t, 5> saved_l(lpointer, 5);
			for (auto [saved, correct] : std::views::zip(saved_h, correct_h)) {
				CHECK(saved == correct);
			}
			for (auto [saved, correct] : std::views::zip(saved_l, correct_l)) {
				CHECK(saved == correct);
			}
		}
		SUBCASE("Basic load") {
			std::unique_ptr<MBC3> uut2(new MBC3(rom, ram, rtc_data, false));
			latch_rtc_regs(uut2.get());
			test_rtc_regs(uut2.get(), {hidden_s, 0, 0, 0, dh});
		}
	}
	SUBCASE("Overflow behaviour") {
		std::uint8_t dh = 0x01;
		std::uint8_t dh_carry = 0x00 | RTC_CRRYBIT;
		set_rtc_regs(uut1.get(), {59, 59, 23, 0xFF, dh});
		std::this_thread::sleep_for(std::chrono::seconds(1));
		latch_rtc_regs(uut1.get());
		test_rtc_regs(uut1.get(), {0, 0, 0, 0, dh_carry});
	}
}

class MBC5 : public Cartridge {
private:
	bool RAM_enable;
	std::uint16_t ROM_bank;
	std::uint8_t RAM_bank;
public:
	MBC5 (
		memory_t ROMBANKS, 
		memory_t RAMBANKS,
		bool hasBattery = false ) {
		ROM = ROMBANKS;
		RAM = RAMBANKS;
		ROM_bank = 0x0001;
		RAM_bank = 0;
		RAM_enable = false;
		hasBattery = hasBattery;
		
	}

	memdata_t read(memaddr_t addr) override {
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
				SDL_Log("WARNING: Attempt to read from disabled cartridge RAM");
				return 0xFF;
			}
			else {
				std::uint16_t ramaddr = (addr & 0x1FFF) | (RAM_bank << 13);
				return RAM[ramaddr % RAM.capacity()];
			}
		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory access at: 0x%X", addr);
			return 0xFF;
		}
	}
	void write(memaddr_t addr, memdata_t data) override {
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
				SDL_Log("WARNING: Attempt to write to disabled cartridge RAM");
			}
			else {
				std::uint16_t ramaddr = (addr & 0x1FFF) | (RAM_bank << 13);
				RAM[ramaddr % RAM.capacity()] = data;
			}
		} 
		else {
			SDL_Log("WARNING: Invalid cartridge memory write at: 0x%X (val=0x%X)", addr, data);
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
		SDL_Log("ROM size: %dKiB (val = 0x%0X)", 32*(1<<header[0x48]), header[0x48]);
	}
	else {
		SDL_Log("ERROR: Invalid ROM size value: 0x%X", header[0x48]);
		return nullptr;
	}
	std::uint32_t ramsize;
	switch (header[0x49]) {
		case 0x00:
			ramsize = 0;
			SDL_Log("RAM size: none");
			break;
		case 0x02:
			ramsize = 0x00002000;
			SDL_Log("RAM size: 8KiB");
			break;
		case 0x03:
			ramsize = 0x00008000;
			SDL_Log("RAM size: 32KiB");
			break;
		case 0x04:
			ramsize = 0x00020000;
			SDL_Log("RAM size: 128KiB");
			break;
		case 0x05:
			ramsize = 0x00010000;
			SDL_Log("RAM size: 64KiB");
			break;
		default:
			SDL_Log("ERROR: Invalid RAM size value: %x", header[0x49]);
			return nullptr;
	}
	memory_t romdata(romsize);
	memory_t ramdata(ramsize);
	RTC_data_t rtc_regs;

	// RTC_regs_t hidden, latched;
	// std::int64_t current_time = MBC3::MBC3_clock::now().time_since_epoch().count();
	// std::int64_t timestamp;

	std::filesystem::path savepath(ROMFILE);
	savepath.replace_extension("sav");
	if ( std::filesystem::exists(savepath) ) {
		std::ifstream savefile(savepath, std::ios::binary | std::ios::ate);
		int filesize = savefile.tellg();
		savefile.seekg(0);
		savefile.read(reinterpret_cast<char*>(ramdata.data()), ramsize);
		if ( filesize > savefile.tellg() ) {
			SDL_Log("Loading RTC data");
			rtc_regs = load_rtc_from_stream(savefile);
			SDL_Log("RTC data loaded");
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
		SDL_Log("No MBC: $%X", header[0x47]);
		romdata = memory_t(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		not_unique = static_cast<Cartridge*>(new NoMBC(romdata, ramsize != 0));
		break;
	case 0x01:
	case 0x02:
	case 0x03:
		SDL_Log("MBC1: $%X", header[0x47]);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		not_unique = static_cast<Cartridge*>(new MBC1(romdata, ramdata, has_battery));
		SDL_Log("Generated ROM size: %d", romdata.capacity());
		SDL_Log("Generated RAM size: %d", ramdata.capacity());
		break;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		SDL_Log("MBC3: $%X", header[0x47]);
		// SDL_Log("WARNING: MBC3 supports timing functionality which is not fully tested\n");
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		mbc = (new MBC3(romdata, ramdata, rtc_regs, has_battery));
		not_unique = static_cast<Cartridge*>(mbc);
		SDL_Log("Generated ROM size: %d", romdata.capacity());
		SDL_Log("Generated RAM size: %d", ramdata.capacity());
		break;
	case 0x19:
	case 0x1A:
	case 0x1B:
		SDL_Log("MBC5: $%X", header[0x47]);
		romdata = memory_t(romsize);
		f.read(reinterpret_cast<char*>(romdata.data()), romsize);
		f.close();
		ramdata = memory_t(ramsize);
		not_unique = static_cast<Cartridge*>(new MBC5(romdata, ramdata, has_battery));
		SDL_Log("Generated ROM size: %d", romdata.capacity());
		SDL_Log("Generated RAM size: %d", ramdata.capacity());
		break;
	default:
		SDL_Log("ERROR: That MBC is not yet implemented: %x", header[0x47]);
		f.close();
		return nullptr;
	}
	cart = std::unique_ptr<Cartridge>(not_unique);
	cart->rompath = ROMFILE;
	return cart;
}