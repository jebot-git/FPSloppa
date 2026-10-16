#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/multiplayer_peer_extension.hpp>
#include <godot_cpp/classes/e_net_connection.hpp>
#include <godot_cpp/classes/e_net_packet_peer.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <vector>
#include "snapshot_delta.h"
// Scene/UI compatibility only. Network traffic belongs to FPSNativeClient.
class FPSClientPeer:public godot::MultiplayerPeerExtension {
 GDCLASS(FPSClientPeer,godot::MultiplayerPeerExtension)
 int id_=0;bool connected_=false;int channel_=0;godot::MultiplayerPeer::TransferMode mode_=godot::MultiplayerPeer::TRANSFER_MODE_RELIABLE;
protected:static void _bind_methods(){}
public:
 void activate(int id){id_=id;connected_=true;}
 int32_t _get_unique_id()const override{return id_;}
 bool _is_server()const override{return false;}
 godot::MultiplayerPeer::ConnectionStatus _get_connection_status()const override{return connected_?godot::MultiplayerPeer::CONNECTION_CONNECTED:godot::MultiplayerPeer::CONNECTION_DISCONNECTED;}
 int32_t _get_available_packet_count()const override{return 0;}
 int32_t _get_max_packet_size()const override{return 65536;}
 godot::Error _put_packet(const uint8_t*,int32_t)override{return godot::ERR_UNAVAILABLE;}
 godot::Error _get_packet(const uint8_t**,int32_t*)override{return godot::ERR_UNAVAILABLE;}
 void _poll()override{}
 void _close()override{connected_=false;}
 void _disconnect_peer(int32_t,bool)override{connected_=false;}
 bool _is_server_relay_supported()const override{return false;}
 int32_t _get_packet_peer()const override{return 1;}
 void _set_transfer_channel(int32_t c)override{channel_=c;}
 int32_t _get_transfer_channel()const override{return channel_;}
 void _set_transfer_mode(godot::MultiplayerPeer::TransferMode m)override{mode_=m;}
 godot::MultiplayerPeer::TransferMode _get_transfer_mode()const override{return mode_;}
 void _set_target_peer(int32_t)override{}
 int32_t _get_packet_channel()const override{return 0;}
 godot::MultiplayerPeer::TransferMode _get_packet_mode()const override{return mode_;}
 void _set_refuse_new_connections(bool)override{}
 bool _is_refusing_new_connections()const override{return true;}
};
class FPSNativeClient:public godot::RefCounted {
 GDCLASS(FPSNativeClient,godot::RefCounted)
 godot::Ref<godot::ENetConnection>host_;godot::Ref<godot::ENetPacketPeer>remote_;godot::Ref<FPSClientPeer>scene_peer_;
 int64_t assembly_=-1,received_=-1;uint32_t raw_size_=0,packed_size_=0,epoch_=0;double origin_=0;size_t parts_received_=0;
 bool delta_enabled_=false;cqsnapshot::History history_;
 std::vector<godot::PackedByteArray>parts_;
 godot::Array decode(const godot::PackedByteArray&);
protected:static void _bind_methods();
public:
 godot::String snapshot_codec()const{return "row-xor-fastlz-v3";}
 godot::Error connect_host(const godot::String&,int);
 godot::Array poll();
 godot::Error send_control(int,const godot::Dictionary&);
 godot::Error send_bytes(int,const godot::PackedByteArray&,int channel=0,bool reliable=true);
 godot::Ref<FPSClientPeer> scene_peer()const{return scene_peer_;}
 void activate(int id){if(scene_peer_.is_valid())scene_peer_->activate(id);}
 void close();
 ~FPSNativeClient(){close();}
};
