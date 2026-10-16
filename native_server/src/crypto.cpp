#include "common.h"
#include "crypto.h"
#include "../vendor/picosha2.h"
#include <array>
#include <cerrno>
#include <fcntl.h>
#include <sys/random.h>
#include <unistd.h>
namespace cqserver {
std::string sha256(const std::vector<uint8_t>&data){return picosha2::hash256_hex_string(data);}
std::string hmac(const std::string&secret,const std::string&message){
 std::vector<uint8_t> key(secret.begin(),secret.end());if(key.size()>64){std::vector<uint8_t> hash(32);picosha2::hash256(key.begin(),key.end(),hash.begin(),hash.end());key=std::move(hash);}key.resize(64);
 std::vector<uint8_t> inner(64),outer(64);for(size_t i=0;i<64;++i){inner[i]=key[i]^0x36;outer[i]=key[i]^0x5c;}
 inner.insert(inner.end(),message.begin(),message.end());std::array<uint8_t,32> digest{};picosha2::hash256(inner.begin(),inner.end(),digest.begin(),digest.end());outer.insert(outer.end(),digest.begin(),digest.end());return sha256(outer);
}
bool constant_equal(const std::string&a,const std::string&b){if(a.size()!=b.size())return false;unsigned result=0;for(size_t i=0;i<a.size();++i)result|=static_cast<unsigned char>(a[i])^static_cast<unsigned char>(b[i]);return result==0;}
std::string random_token(size_t bytes){if(bytes>64)throw std::runtime_error("Excessive random token");std::vector<uint8_t> data(bytes);size_t at=0;while(at<bytes){ssize_t count=getrandom(data.data()+at,bytes-at,0);if(count<0){if(errno==EINTR)continue;throw std::runtime_error("System random source failed");}at+=size_t(count);}return picosha2::bytes_to_hex_string(data.begin(),data.end());}
void atomic_write(const std::filesystem::path &path,const std::vector<uint8_t>&bytes){
 if(!path.parent_path().empty())std::filesystem::create_directories(path.parent_path());auto temp=path;temp+="."+random_token(8)+".tmp";
 int fd=open(temp.c_str(),O_CREAT|O_EXCL|O_WRONLY|O_CLOEXEC,0600);if(fd<0)throw std::runtime_error("Cannot create atomic output");size_t at=0;bool ok=true;
 while(at<bytes.size()){ssize_t count=write(fd,bytes.data()+at,bytes.size()-at);if(count<0){if(errno==EINTR)continue;ok=false;break;}at+=size_t(count);}if(fsync(fd)!=0)ok=false;if(close(fd)!=0)ok=false;
 if(!ok){std::filesystem::remove(temp);throw std::runtime_error("Atomic output write failed");}std::filesystem::rename(temp,path);
}
}
