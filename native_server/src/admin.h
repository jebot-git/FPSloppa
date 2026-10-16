#pragma once
#include "config.h"
#include <functional>
#include <memory>
namespace cqserver {
class Logger {
 std::filesystem::path path_;size_t limit_;int backups_;std::string level_;
public:
 explicit Logger(const Config&);
 void write(const std::string&,const Json& =Json::object());
 void level(std::string value){level_=std::move(value);}
};
class Rcon {
 struct Impl;std::unique_ptr<Impl>p_;
public:
 explicit Rcon(const Config&);
 ~Rcon();
 void poll(double,const std::function<Json(const std::string&)>&);
};
}
