#pragma once
#include <string>
#include <vector>
#include <cstdint>
namespace cqserver {
std::string sha256(const std::vector<uint8_t>&);
std::string hmac(const std::string&,const std::string&);
bool constant_equal(const std::string&,const std::string&);
std::string random_token(size_t bytes=32);
}
