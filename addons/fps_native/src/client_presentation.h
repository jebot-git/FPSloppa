#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
namespace cqclient {
// Compatibility projection of a decoded frame; never accesses scene objects.
godot::Array project_frame(const godot::Dictionary&,double origin,int64_t epoch,double duration);
}
