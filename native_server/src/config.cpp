#include "config.h"
#include <charconv>
#include <cctype>
#include <sstream>
namespace cqserver {
Tokens tokenize(const std::string&line){
 Tokens out;std::string word;bool quoted=false,started=false;
 for(size_t i=0;i<line.size();++i){char c=line[i];
  if(!quoted&&(c=='#'||(c=='/'&&i+1<line.size()&&line[i+1]=='/')))break;
  if(c=='"'){quoted=!quoted;started=true;}
  else if(c=='\\'&&quoted&&i+1<line.size()&&(line[i+1]=='"'||line[i+1]=='\\'))word+=line[++i];
  else if(!quoted&&(c==' '||c=='\t'||c=='\r')){if(started){out.words.push_back(word);word.clear();started=false;}}
  else if(!quoted&&c==';'){out.error="Semicolon commands are not supported";return out;}
  else{word+=c;started=true;}
 }
 if(quoted){out.error="Unclosed quote";return out;}if(started)out.words.push_back(word);return out;
}
Config::Config(){values={{"sv_cq_snapshot_delta","1"},{"sv_cq_snapshot_relevance","1"},{"sv_cq_adaptive_tick","1"},{"sv_cq_tick_rate","60"},{"sv_cq_backend","monolithic"},{"sv_cq_worker_limit","16"},{"sv_bot_fill","0"},{"sv_cq_bot_fill","0"},{"sv_cq_maxclients","64"},{"sv_maxclients","32"},{"sv_hostname","FPSloppa CQ"},{"net_ip","*"},{"net_port","7777"},{"fraglimit","100"},{"timelimit","15"},{"sv_gametype","cq"},{"sv_gametypes","cq"},{"sv_weapon_rules","ut99"},{"sv_lobby","0"},{"sv_lobby_seconds","45"},{"sv_log_level","normal"},{"sv_log_file",""},{"sv_log_max_mb","8"},{"sv_log_backups","3"},{"sv_voice","1"},{"sv_tf_spy_invisibility","0"},{"sv_announcer","0"},{"sv_voice_backend","builtin"},{"sv_mumble_url",""},{"sv_votes","0"},{"sv_map_uploads","0"},{"map","voxel_jungle"},{"sv_maplist","voxel_jungle"},{"sv_friendlyfire","0"},{"capturelimit","5"},{"hilllimit","120"},{"rcon_password",""},{"rcon_port","7778"},{"rcon_bind","127.0.0.1"},{"sv_cq_destruction","1"}};
 for(auto mode:{"dm","tdm","ctf","koth","ig","if","ft","cc","tf","tb","as","cq"})values[std::string(mode)+"_maplist"]="";
}
const std::string&Config::text(const std::string&key)const{return values.at(key);}
int Config::number(const std::string&key)const{const auto&s=text(key);int n=0;auto r=std::from_chars(s.data(),s.data()+s.size(),n);if(r.ec!=std::errc()||r.ptr!=s.data()+s.size())throw std::runtime_error("Invalid integer for "+key);return n;}
Config Config::load(const std::filesystem::path&p){auto b=read_file(p,65536);return parse({b.begin(),b.end()});}
Config Config::parse(const std::string&source){
 if(source.size()>65536)throw std::runtime_error("Server config exceeds 64 KiB");Config c;
 const std::map<std::string,std::pair<int,int>>ranges={{"sv_cq_snapshot_delta",{0,1}},{"sv_cq_snapshot_relevance",{0,1}},{"sv_cq_adaptive_tick",{0,1}},{"sv_cq_tick_rate",{30,60}},{"sv_cq_worker_limit",{2,16}},{"sv_cq_maxclients",{2,64}},{"sv_cq_bot_fill",{0,64}},{"sv_bot_fill",{0,64}},{"rcon_port",{1024,65535}},{"sv_lobby",{0,1}},{"sv_lobby_seconds",{15,180}},{"sv_map_uploads",{0,1}},{"sv_log_max_mb",{1,512}},{"sv_log_backups",{1,9}},{"sv_friendlyfire",{0,1}},{"capturelimit",{1,100}},{"hilllimit",{1,3600}},{"net_port",{1024,65535}},{"sv_maxclients",{1,64}},{"fraglimit",{1,100}},{"timelimit",{1,60}},{"sv_votes",{0,1}},{"sv_tf_spy_invisibility",{0,1}},{"sv_announcer",{0,1}},{"sv_voice",{0,1}},{"sv_cq_destruction",{0,1}}};
 std::istringstream lines(source);std::string line;size_t index=0;
 while(std::getline(lines,line)){++index;auto t=tokenize(line);auto fail=[&](const std::string&e){throw std::runtime_error("Line "+std::to_string(index)+": "+e);};if(!t.error.empty())fail(t.error);if(t.words.empty())continue;
  std::string key,value;
  if(t.words.size()==3&&(t.words[0]=="set"||t.words[0]=="seta"||t.words[0]=="sets")){key=t.words[1];value=t.words[2];}
  else if(t.words.size()==2&&t.words[0]=="map"){key="map";value=t.words[1];}else fail("Expected set/seta/sets <name> <value>, or map <id>");
  if(key=="koth_move_points"||key=="sv_tb_heavy_ordnance"||key=="sv_cq_quake_movement")continue;
  if(!c.values.count(key))fail("Unsupported setting "+key);
  c.values[key]=value;
  auto range=ranges.find(key);if(range!=ranges.end()){int n=c.number(key);if(n<range->second.first||n>range->second.second)fail(key+" is out of range");}
  else if(value.size()>(key.find("maplist")!=std::string::npos?2048:key=="sv_log_file"||key=="sv_mumble_url"?512:80))fail("Excessive value");
 }
 if(c.number("sv_cq_tick_rate")!=30&&c.number("sv_cq_tick_rate")!=60)throw std::runtime_error("sv_cq_tick_rate must be 30 or 60");
 if(c.text("sv_cq_backend")!="monolithic")throw std::runtime_error("Standalone CQ uses one native authority; district workers are unsupported");
 if(c.enabled("sv_map_uploads"))throw std::runtime_error("Standalone CQ uses its cooked world; map uploads are unsupported");
 if(c.text("sv_gametype")!="cq"||c.enabled("sv_lobby")||c.text("sv_voice_backend")!="builtin")throw std::runtime_error("Standalone server requires CQ, no lobby and built-in voice routing");
 if(c.text("map")!="voxel_jungle"||(!c.text("sv_gametypes").empty()&&c.text("sv_gametypes")!="cq"))throw std::runtime_error("Standalone CQ cannot change mode or map");
 if(std::max(c.number("sv_cq_bot_fill"),c.number("sv_bot_fill"))>c.capacity())throw std::runtime_error("Bot fill exceeds CQ capacity");
 if(c.text("sv_log_level")!="off"&&c.text("sv_log_level")!="normal"&&c.text("sv_log_level")!="verbose")throw std::runtime_error("Invalid log level");
 c.values["sv_weapon_rules"]="ut99";return c;
}
std::string clean_name(const std::string&s){std::string out;size_t count=0;for(size_t i=0;i<s.size()&&count<24;){unsigned char c=s[i];size_t width=c<128?1:(c&0xe0)==0xc0?2:(c&0xf0)==0xe0?3:(c&0xf8)==0xf0?4:0;if(!width||i+width>s.size())break;bool good=true;for(size_t j=1;j<width;++j)good&=(static_cast<unsigned char>(s[i+j])&0xc0)==0x80;if(!good)break;if(c>=32&&c!=127){out.append(s,i,width);++count;}i+=width;}while(!out.empty()&&out.back()==' ')out.pop_back();auto start=out.find_first_not_of(' ');if(start==std::string::npos)return "Player";return out.substr(start);}
}
