#include "admin.h"
#include "crypto.h"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <cerrno>
#include <iostream>
#include <map>
namespace cqserver {
Logger::Logger(const Config&c):path_(c.text("sv_log_file")),limit_(size_t(c.number("sv_log_max_mb"))*1024*1024),backups_(c.number("sv_log_backups")),level_(c.text("sv_log_level")){}
void Logger::write(const std::string&event,const Json&fields){if(level_=="off")return;Json row={{"event",event},{"fields",fields},{"utc_seconds",std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count()}};auto line=row.dump()+"\n";std::cout<<line<<std::flush;if(path_.empty())return;if(!path_.parent_path().empty())std::filesystem::create_directories(path_.parent_path());if(std::filesystem::exists(path_)&&std::filesystem::file_size(path_)+line.size()>limit_){for(int i=backups_;i>0;--i){auto to=path_;to+="."+std::to_string(i);auto from=path_;if(i>1)from+="."+std::to_string(i-1);if(std::filesystem::exists(from)){std::error_code ec;std::filesystem::remove(to,ec);std::filesystem::rename(from,to);}}}std::ofstream file(path_,std::ios::app);if(!file||!(file<<line))throw std::runtime_error("Server log write failed");}
struct Rcon::Impl {
 int listener=-1;std::string secret;
 struct Client{int fd=-1;double deadline=0;std::string nonce,input,output;size_t sent=0;bool replied=false;};std::vector<Client>clients;
 struct Limit{double start=0;int count=0;};std::map<uint32_t,Limit>limits;
 ~Impl(){for(auto&c:clients)close(c.fd);if(listener>=0)close(listener);}
};
Rcon::Rcon(const Config&c):p_(std::make_unique<Impl>()){p_->secret=c.text("rcon_password");if(p_->secret.empty())return;p_->listener=socket(AF_INET,SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC,0);if(p_->listener<0)throw std::runtime_error("Cannot create RCON socket");int yes=1;setsockopt(p_->listener,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof(yes));sockaddr_in address{};address.sin_family=AF_INET;address.sin_port=htons(uint16_t(c.number("rcon_port")));if(inet_pton(AF_INET,c.text("rcon_bind").c_str(),&address.sin_addr)!=1)throw std::runtime_error("RCON bind must be IPv4 address");if(bind(p_->listener,reinterpret_cast<sockaddr*>(&address),sizeof(address))||listen(p_->listener,8))throw std::runtime_error("Cannot bind RCON socket");}
Rcon::~Rcon()=default;
void Rcon::poll(double now,const std::function<Json(const std::string&)>&command){if(p_->listener<0)return;for(int accepted=0;accepted<4;++accepted){sockaddr_in at{};socklen_t size=sizeof(at);int fd=accept4(p_->listener,reinterpret_cast<sockaddr*>(&at),&size,SOCK_NONBLOCK|SOCK_CLOEXEC);if(fd<0)break;auto found=p_->limits.find(at.sin_addr.s_addr);if(found==p_->limits.end()){for(auto it=p_->limits.begin();it!=p_->limits.end();)if(now-it->second.start>60)it=p_->limits.erase(it);else ++it;if(p_->limits.size()>=256){close(fd);continue;}found=p_->limits.emplace(at.sin_addr.s_addr,Impl::Limit{now,0}).first;}auto&limit=found->second;if(now-limit.start>=60)limit={now,0};if(++limit.count>12||p_->clients.size()>=8){close(fd);continue;}Impl::Client client;client.fd=fd;client.deadline=now+5;client.nonce=random_token();client.output=Json{{"protocol","fpsloppa-rcon-1"},{"nonce",client.nonce}}.dump()+"\n";p_->clients.push_back(std::move(client));}
 for(auto it=p_->clients.begin();it!=p_->clients.end();){auto&c=*it;bool dead=now>=c.deadline;char bytes[4096];if(!dead&&!c.replied){ssize_t n=recv(c.fd,bytes,sizeof(bytes),0);if(n>0){c.input.append(bytes,size_t(n));if(c.input.size()>4096)dead=true;auto end=c.input.find('\n');if(end!=std::string::npos&&!dead){try{auto request=Json::parse(c.input.substr(0,end));auto line=request.at("command").get<std::string>();if(line.size()>1024||line.find_first_of("\r\n")!=std::string::npos||!constant_equal(request.at("mac").get<std::string>(),hmac(p_->secret,c.nonce+"\n"+line)))throw std::runtime_error("Authentication failed");auto result=command(line).dump();c.output+=Json{{"result",result},{"mac",hmac(p_->secret,c.nonce+"\nresponse\n"+result)}}.dump()+"\n";c.replied=true;}catch(const std::exception&){dead=true;}}}else if(n==0||(n<0&&errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR))dead=true;}
  if(!dead&&c.sent<c.output.size()){ssize_t n=send(c.fd,c.output.data()+c.sent,c.output.size()-c.sent,MSG_NOSIGNAL);if(n>0)c.sent+=size_t(n);else if(n<0&&errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR)dead=true;}if(c.replied&&c.sent==c.output.size())dead=true;if(dead){close(c.fd);it=p_->clients.erase(it);}else ++it;
 }
}
}
