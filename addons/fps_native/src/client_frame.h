#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
namespace cqclient {
// Complete validated immutable frame -> compatibility view. No scene access.
godot::Dictionary decode_frame(const godot::PackedByteArray &bytes, bool validated=false);
}
