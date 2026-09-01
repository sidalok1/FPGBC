#pragma once
namespace bitops {
	template <typename T, typename U>
	T getbit(T num, U idx);

	template <typename T, typename U>
	T setbit(T num, U idx);

	template <typename T, typename U>
	T clrbit(T num, U idx);

	template <typename T, typename U>
	bool tstbit(T num, U idx);

	template <typename T, typename U>
	T bitslc(T num, U lhs, U rhs);
}

#include <cstdint>
#include <type_traits>
#include <ranges>
#include <utility>
#include <cmath>
#include "doctest.h"

template <typename T, typename U>
T bitops::getbit(T num, U idx) {
	return (num >> idx) & 0b1;
}

TEST_CASE("Tests for getbit") {
	std::uint8_t all_set = 0xFF;
	std::uint16_t all_clr = 0;
	std::uint8_t pattern = 0b01011010;

	std::uint8_t reconstructed = 0;
	for (auto i : std::views::indices(8)) {
		CHECK(bitops::getbit(all_set, i) == 1);
		CHECK(bitops::getbit(all_clr, i) == 0);
		reconstructed |= bitops::getbit(pattern, i) << i;
	}
	CHECK(reconstructed == pattern);
}

template <typename T, typename U>
T bitops::setbit(T num, U idx) {
	return num | (0b1 << idx);
}

TEST_CASE("Tests for setbit") {
	std::uint8_t 
		pattern1 = 0b11111111,
		pattern2 = 0b01010101,
		pattern3 = 0b00010001,
		reconst1 = 0,
		reconst2 = 0,
		reconst3 = 0;
	for ( auto i : std::views::indices(8) ) {
		reconst1 = bitops::setbit(reconst1, i);
		if ( i % 2 == 0 ) {
			reconst2 = bitops::setbit(reconst2, i);
		}
		if ( i % 4 == 0 ) {
			reconst3 = bitops::setbit(reconst3, i);
		}
	}
	CHECK(reconst1 == pattern1);
	CHECK(reconst2 == pattern2);
	CHECK(reconst3 == pattern3);
	CHECK(bitops::setbit(0x01, 0) == 0x01);
}

template <typename T, typename U>
T bitops::clrbit(T num, U idx) {
	return num & ~(0b1 << idx);
}

TEST_CASE("Tests for clrbit") {
	auto a = 0b0, b = 0b1;
	CHECK(bitops::clrbit(a, 0) == a);
	CHECK(bitops::clrbit(b, 0) != b);
}

template <typename T, typename U>
bool bitops::tstbit(T num, U idx) {
	return bitops::getbit(num, idx) == 0b1;
}

template <typename T, typename U>
T bitops::bitslc(T num, U lhs, U rhs) {
	return (num & ((0b1<<(lhs+1))-1)) >> rhs;
}

TEST_CASE("Tests for bitslc") {
	auto bitvec = 0b1111010100110000;
	CHECK(bitops::bitslc(bitvec, 3, 0) == 0b0000);
	CHECK(bitops::bitslc(bitvec, 7, 4) == 0b0011);
	CHECK(bitops::bitslc(bitvec, 11, 8) == 0b0101);
	CHECK(bitops::bitslc(bitvec, 15, 12) == 0b1111);
	CHECK(bitops::bitslc(bitvec, 11, 4) == 0b01010011);
	CHECK(bitops::bitslc(bitvec, 10, 10) == 0b1);
}