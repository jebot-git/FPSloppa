#include "server.h"
#include <iostream>
#include <csignal>
std::atomic<bool> stopped{false};
void signal_stop(int){stopped.store(true);}
int main(int argc,char**argv){try{
 cqserver::RunOptions options;std::filesystem::path config;bool check=false;
 for(int i=1;i<argc;++i){std::string arg=argv[i];auto value=[&](){if(++i>=argc)throw std::runtime_error("Missing value for "+arg);return std::string(argv[i]);};if(arg=="--world")options.world=value();else if(arg=="--config")config=value();else if(arg=="--state")options.state=value();else if(arg=="--duration")options.duration=std::stod(value());else if(arg=="--report")options.report=value();else if(arg=="--fast")options.fast=true;else if(arg=="--check-world"){check=true;options.world=value();}else if(arg=="--help"){std::cout<<"cq-server --world <cooked-directory> [--config server.cfg] [--state directory] [--duration seconds] [--report json]\n";return 0;}else throw std::runtime_error("Unknown option "+arg);}
 if(options.world.empty())throw std::runtime_error("--world is required");
 if(check){cqserver::WorldData data(options.world);auto core=std::make_unique<cqauthority::Core>();cqauthority::CqConfig settings;settings.enabled=true;core->configure_cq(settings);core->terrain=data.terrain();cqserver::World world(data,*core);cqserver::Assets assets(data,"/tmp/cq-standalone-check-assets");cqserver::Destruction destruction(world,*core,true);std::cout<<"CQ_WORLD_VALID "<<cqserver::Json{{"avatars",assets.items().size()},{"bodies",data.metadata.at("bodies").size()},{"ground",world.ground_height(-850,-600)}}.dump()<<std::endl;return 0;}
 std::signal(SIGINT,signal_stop);std::signal(SIGTERM,signal_stop);cqserver::Server server(config.empty()?cqserver::Config():cqserver::Config::load(config),options);return server.run(stopped);
 }catch(const std::exception&e){std::cerr<<"CQ_FATAL "<<e.what()<<std::endl;return 1;}}
