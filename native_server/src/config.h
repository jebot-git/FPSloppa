#pragma once
#include "common.h"
#include <map>
namespace cqserver {
struct Tokens {std::vector<std::string> words;std::string error;};
Tokens tokenize(const std::string&);
struct Config {
 std::map<std::string,std::string> values;
 Config();
 static Config parse(const std::string&);
 static Config load(const std::filesystem::path&);
 int number(const std::string &key)const;
 const std::string &text(const std::string &key)const;
 bool enabled(const std::string &key)const{return number(key)!=0;}
 int capacity()const{return number("sv_cq_maxclients");}
};
struct TokenBucket {
 double tokens=12,last=0,capacity=12,rate=60;
 bool take(double now,double count=1){if(!std::isfinite(now)||now<last)return false;tokens=std::min(capacity,tokens+(now-last)*rate);last=now;if(tokens<count)return false;tokens-=count;return true;}
};
std::string clean_name(const std::string&);
}
