#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
namespace godot {
// Stateless calls keep scratch buffers private, including during recursive values.
class FPSCodec : public RefCounted {
 GDCLASS(FPSCodec, RefCounted)
protected:
 static void _bind_methods();
public:
 PackedByteArray encode(const Variant &value) const;
 PackedByteArray pack_input(const Dictionary &command) const;
 Dictionary snapshot_records(const Array &snapshot,int64_t recipient,Dictionary cadence,Dictionary cached,Dictionary shared) const;
 Array encode_records(const Array &records) const;
 Dictionary pack_records(const Array &records,const Array &header) const;
 Variant decode(const PackedByteArray &bytes) const;
};
}
