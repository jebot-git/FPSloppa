#pragma once
#include "authority_math.h"
#include <cstdint>
#include <cstring>
#include <type_traits>
#include <vector>
namespace cqauthority::wire {
template <class T> inline void append(std::vector<uint8_t> &bytes, T value) {
  static_assert(std::is_integral<T>::value, "integer wire");
  using U = typename std::make_unsigned<T>::type;
  U u = static_cast<U>(value);
  for (size_t i = 0; i < sizeof(T); ++i)
    bytes.push_back(uint8_t(u >> (8 * i)));
}
inline void real(std::vector<uint8_t> &b, double value) {
  float f = static_cast<float>(value);
  uint32_t bits;
  std::memcpy(&bits, &f, 4);
  append(b, bits);
}
inline void vec(std::vector<uint8_t> &b, V v) {
  real(b, v.x);
  real(b, v.y);
  real(b, v.z);
}
inline void transform(std::vector<uint8_t> &b, const T &t) {
  for (V v : {t.basis.x, t.basis.y, t.basis.z, t.origin})
    vec(b, v);
}
struct Section {
  std::vector<uint8_t> &out;
  size_t length_at, start;
  Section(std::vector<uint8_t> &b, uint16_t type) : out(b) {
    append(out, type);
    length_at = out.size();
    append(out, uint32_t(0));
    start = out.size();
  }
  ~Section() {
    uint32_t n = out.size() - start;
    for (int i = 0; i < 4; ++i)
      out[length_at + i] = uint8_t(n >> (i * 8));
  }
};
} // namespace cqauthority::wire
