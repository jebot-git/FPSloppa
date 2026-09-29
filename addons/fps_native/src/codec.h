#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
namespace godot {
// Stateless calls keep scratch buffers private, including during recursive values.
class FPSCodec : public RefCounted {
 GDCLASS(FPSCodec, RefCounted)
protected:
 static void _bind_methods();
public:
 PackedByteArray encode(const Variant &value) const;
 Variant decode(const PackedByteArray &bytes) const;
};
}
