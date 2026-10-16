#include "snapshot_interest.h"
#include "authority_protocol.h"
namespace cqserver {
SnapshotView::SnapshotView(const std::vector<uint8_t>&s):source(s){
 if(!cqauthority::validate_frame(s.data(),s.size()))throw std::runtime_error("Invalid authority snapshot");size_t count=uint16_t(s[12])|(uint16_t(s[13])<<8);head=14+count*104;players.reserve(count);std::map<int64_t,int>indices;
 for(size_t at=14;at<head;at+=104){int64_t id=int64_t(u64(s.data()+at));indices[id]=int(players.size());players.push_back({id,{f32(s.data()+at+16),f32(s.data()+at+20),f32(s.data()+at+24)},s[at+14]});}
 for(size_t at=head;at<s.size();){uint16_t type=uint16_t(s[at])|(uint16_t(s[at+1])<<8);size_t end=at+6+u32(s.data()+at+2);Section section{type,at,end,{}};
  if(type==1||type==2)for(size_t row=at+8;row<end;){size_t size=type==1?(s[row+12]&2?257:209):42;section.rows.push_back({row,size,indices.at(int64_t(u64(s.data()+row))),type==2?s[row+12]:-1});row+=size;}
  sections.push_back(std::move(section));at=end;
 }
}
std::vector<uint8_t>SnapshotInterest::filter(const SnapshotView&view,int64_t viewer){
 const auto&s=view.source;V eye;bool found=false;for(auto&p:view.players)if(p.id==viewer){eye=p.position;found=true;break;}if(!found){near.clear();return s;}
 std::array<bool,128>detail{};std::set<int64_t>updated;
 for(size_t i=0;i<view.players.size();++i){auto&p=view.players[i];double radius=near.count(p.id)?160.:128.;if(p.id==viewer||(p.position-eye).length2()<=radius*radius){detail[i]=true;updated.insert(p.id);}}
 near=std::move(updated);std::vector<uint8_t>out;out.reserve(s.size());out.insert(out.end(),s.begin(),s.begin()+view.head);
 for(auto&section:view.sections){if(section.type!=1&&section.type!=2){out.insert(out.end(),s.begin()+section.at,s.begin()+section.end);continue;}size_t start=out.size();out.insert(out.end(),s.begin()+section.at,s.begin()+section.at+8);uint16_t kept=0;
  for(auto&row:section.rows){auto&p=view.players[size_t(row.player)];if(p.id==viewer||(detail[size_t(row.player)]&&(section.type==1||row.weapon==p.weapon))){out.insert(out.end(),s.begin()+row.at,s.begin()+row.at+row.size);++kept;}}
  uint32_t size=uint32_t(out.size()-start-6);for(int i=0;i<4;++i)out[start+2+i]=uint8_t(size>>(8*i));out[start+6]=uint8_t(kept);out[start+7]=uint8_t(kept>>8);
 }
 return out;
}
}
