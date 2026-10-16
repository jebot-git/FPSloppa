#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <map>
#include <set>
#include <cstdint>

// Per-connection frontend state. Scene factories/UI remain main-thread adapters.
class FPSClientSession : public godot::RefCounted {
 GDCLASS(FPSClientSession, godot::RefCounted)
 struct Member { uint64_t binding=0; int64_t life=-1; bool dead=false; int team=-99,color=-1; godot::String name; };
 std::map<int64_t, Member> members_;
 godot::Dictionary catalog_;
 int64_t generation_=0, epoch_=-1, mine_=0, tick_=-1, event_=0, round_=-1, sequence_=0;
 bool admitted_=false, deployment_=false, staging_=false;
protected:
 static void _bind_methods();
public:
 void reset();
 godot::Dictionary welcome(const godot::Dictionary &data,const godot::String &map_hash);
 godot::Dictionary catalog_update(const godot::Array &rows);
 godot::Dictionary roster_plan(const godot::Array &rows,const godot::Dictionary &entries,const godot::Array &queued,const godot::String &requested,const godot::String &downloading,const godot::Dictionary &players);
 bool apply_roster(godot::Node *arena,const godot::Array &rows,const godot::Array &team_colors,const godot::Array &palette,int64_t mine);
 godot::Dictionary accept_frame(const godot::Dictionary &frame,double origin,int64_t epoch);
 godot::Array actions(int kind,int64_t life,int a,int b,int c);
 godot::Dictionary stats() const;
};
