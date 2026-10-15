#include "authority_protocol.h"
#include <array>
#include <cmath>
#include <cstring>
namespace cqauthority {
bool validate_frame(const uint8_t *data, size_t length, int expected,
                    int64_t tick) {
  if (!data || length < 14 || length > 1048576 || std::memcmp(data, "CQA", 3) ||
      (data[3] != '1' && data[3] != '2'))
    return false;
  auto integer = [&](size_t at, size_t size) {
    uint64_t value = 0;
    for (size_t i = 0; i < size; ++i)
      value |= uint64_t(data[at + i]) << (8 * i);
    return value;
  };
  auto finite = [&](size_t at) {
    uint32_t bits = uint32_t(integer(at, 4));
    float value;
    std::memcpy(&value, &bits, 4);
    return std::isfinite(value);
  };
  size_t count = integer(12, 2);
  if (count > 128 || (expected >= 0 && count != size_t(expected)) ||
      (tick >= 0 && integer(4, 8) != uint64_t(tick)) ||
      length < 14 + count * 104)
    return false;
  std::array<uint64_t, 128> ids{};
  std::array<uint32_t, 128> lives{};
  auto player = [&](size_t at) {
    uint64_t id = integer(at, 8);
    uint32_t life = integer(at + 8, 4);
    for (size_t i = 0; i < count; ++i)
      if (ids[i] == id && lives[i] == life)
        return int(i);
    return -1;
  };
  size_t at = 14;
  for (size_t i = 0; i < count; ++i, at += 104) {
    ids[i] = integer(at, 8);
    lives[i] = integer(at + 8, 4);
    if (!ids[i] || !lives[i] || data[at + 12] > 2 || data[at + 13] > 1 ||
        data[at + 14] > 11 || data[at + 15] > 1)
      return false;
    for (size_t j = 0; j < i; ++j)
      if (ids[j] == ids[i])
        return false;
    for (size_t j = 16; j < 56; j += 4)
      if (!finite(at + j))
        return false;
  }
  if (data[3] == '1')
    return at == length;
  uint32_t sections = 0;
  while (at < length) {
    if (length - at < 8)
      return false;
    uint16_t type = integer(at, 2);
    size_t size = integer(at + 2, 4);
    at += 6;
    if (size < 2 || size > length - at || !type)
      return false;
    if (type < 32) {
      uint32_t bit = uint32_t(1) << type;
      if (sections & bit)
        return false;
      sections |= bit;
    }
    size_t end = at + size, rows = integer(at, 2);
    at += 2;
    if (type > 15) {
      at = end;
      continue;
    }
    static constexpr std::array<size_t, 16> row_sizes{
        {0, 0, 42, 67, 41, 147, 0, 36, 47, 98, 74, 79, 54, 63, 83, 17}},
        caps{{0, 128, 1536, 2048, 128, 128, 32, 384, 128, 32, 128, 128, 384,
              1024, 128, 128}};
    if (rows > caps[type])
      return false;
    if (type == 6) {
      if (end - at != 29 + rows * 30)
        return false;
      for (size_t o :
           {size_t(5), size_t(9), size_t(17), size_t(21), size_t(25)})
        if (!finite(at + o))
          return false;
      at += 29;
      for (size_t i = 0; i < rows; ++i, at += 30) {
        for (size_t o = 0; o < 16; o += 4)
          if (!finite(at + o))
            return false;
        for (size_t o : {size_t(17), size_t(21), size_t(25)})
          if (!finite(at + o))
            return false;
        if (data[at + 29] > 1)
          return false;
      }
      continue;
    }
    std::array<uint16_t, 128> seen{};
    for (size_t i = 0; i < rows; ++i) {
      size_t row_size = row_sizes[type];
      if (type == 1) {
        if (end - at < 209 || data[at + 12] & ~3)
          return false;
        row_size = data[at + 12] & 2 ? 257 : 209;
      }
      if (end - at < row_size)
        return false;
      if (type == 1 || type == 2 || type == 4 || type == 5 || type == 14 || type == 15) {
        int index = player(at);
        if (index < 0)
          return false;
        uint16_t bit = 1;
        if (type == 2) {
          if (data[at + 12] > 11)
            return false;
          bit = uint16_t(1) << data[at + 12];
        }
        if (seen[index] & bit)
          return false;
        seen[index] |= bit;
      }
      auto floats = [&](size_t begin, size_t finish) {
        for (size_t j = begin; j < finish; j += 4)
          if (!finite(at + j))
            return false;
        return true;
      };
      bool ok = true;
      switch (type) {
      case 1:
        ok = floats(13, row_size);
        break;
      case 2:
        ok = finite(at + 17) && finite(at + 23) && finite(at + 28) &&
             finite(at + 32);
        break;
      case 3:
        ok = integer(at, 8) && floats(22, 50) && data[at + 50] < 4 &&
             floats(51, 67);
        break;
      case 4:
        ok = data[at + 12] <= 4 && floats(13, 37);
        break;
      case 5:
        ok = data[at + 12] < 4 && data[at + 13] < 4 &&
             (data[at + 14] == 1 || data[at + 14] == 2) &&
             (data[at + 15] >> 5) == 0 && int8_t(data[at + 146]) >= -1 && int8_t(data[at + 146]) < 8 && floats(46, 54) && floats(66, 102) &&
             floats(103, 143);
        break;
      case 7:
        ok = integer(at, 8) && data[at + 21] <= 1 && floats(22, 34);
        break;
      case 8:
        ok = integer(at, 8) && floats(21, 33) && floats(35, 47);
        break;
      case 9:
        ok = integer(at, 8) && data[at + 8] < 32 && data[at + 9] < 4 &&
             data[at + 11] <= 1 && floats(24, 96);
        break;
      case 10:
        ok = integer(at, 8) && floats(21, 49) && finite(at + 50);
        break;
      case 11:
        ok = integer(at, 8) && data[at + 8] <= 1 && floats(22, 78);
        break;
      case 12:
        ok = integer(at, 8) && data[at + 25] <= 3 && floats(26, 54);
        break;
      case 13:
        ok = integer(at, 8) && data[at + 8] <= 9 && floats(29, 61);
        break;
      case 15:
        ok=data[at+12]<=4&&finite(at+13);break;
      case 14:
        ok = !(integer(at + 12, 2) & ~4095) && floats(14, 30) &&
             floats(38, 46) && data[at + 46] <= 7 && floats(47, 55) &&
             finite(at + 56) && finite(at + 61) && finite(at + 65);
        break;
      }
      if (!ok)
        return false;
      at += row_size;
    }
    if (at != end)
      return false;
    if ((type == 5 || type == 14 || type == 15) && rows != count)
      return false;
  }
  return at == length;
}
} // namespace cqauthority
