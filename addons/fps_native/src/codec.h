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
 Array project_authority_frame(const Dictionary &frame,double origin,int64_t epoch,double duration) const;
 PackedByteArray encode_authority_input(const Dictionary &command) const;
 Dictionary decode_authority_frame(const PackedByteArray &bytes) const;
 bool validate_authority_frame(const PackedByteArray &bytes,int expected,int64_t tick) const;
 PackedByteArray encode(const Variant &value) const;
 PackedByteArray pack_input(const Dictionary &command) const;
 Array encode_records(const Array &records) const;
 Dictionary pack_records(const Array &records,const Array &header,bool compression=false) const;
 Variant decode(const PackedByteArray &bytes) const;
};
}
