// SPDX-License-Identifier: LGPL-3.0-or-later
use godot::prelude::*;
use btleplug::api::{Central, Manager as _, Peripheral as _, ScanFilter};
use btleplug::platform::{Adapter, Manager, Peripheral};
use freehaptics::device::{BHapticsDevice, mapping::{AttachmentPoint, Mapping}};
use freehaptics::proto::motor::VestMotorFrame;
use std::{future::Future, sync::{Arc, Mutex, MutexGuard}, thread::{self, JoinHandle}, time::{Duration, Instant}};

const MOTOR_UUID: &str = "6e40000a-b5a3-f393-e0a9-e50e24dcca9e";
const FRAME_TTL: Duration = Duration::from_millis(200);

#[cfg(target_os = "android")]
static ANDROID_READY: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
#[cfg(target_os = "android")]
static ANDROID_VM: std::sync::OnceLock<jni::JavaVM> = std::sync::OnceLock::new();

// Called from the companion Godot Android plugin with its application class loader.
#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub extern "system" fn Java_org_fpsloppa_bhaptics_BhapticsAndroid_nativeInitialize(
    env: jni::JNIEnv, _class: jni::objects::JClass,
) -> jni::sys::jboolean {
    use std::sync::atomic::Ordering;
    if ANDROID_READY.load(Ordering::Acquire) { return 1; }
    let initialized = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let vm = env.get_java_vm().map_err(|e| e.to_string())?;
        let _ = ANDROID_VM.set(vm);
        jni_utils::init(&env).map_err(|e| e.to_string())?;
        btleplug::platform::init(&env).map_err(|e| e.to_string())
    }));
    if matches!(initialized, Ok(Ok(()))) {
        ANDROID_READY.store(true, Ordering::Release); 1
    } else {
        // Do not propagate a pending JNI exception into Godot's render loop.
        let _ = env.exception_clear(); 0
    }
}

#[derive(Clone)]
struct DeviceInfo { id: String, name: String }
struct Shared {
    status: String,
    devices: Vec<DeviceInfo>,
    scan: bool,
    connect: Option<String>,
    quit: bool,
    connected: bool,
    frame: [u8; 40],
    deadline: Instant,
    writes: u64,
    active_writes: u64,
    last_active_motors: usize,
    last_frame: [u8; 40],
    motor_mask: u64,
    frame_changes: u64,
    write_errors: u64,
    connections: u64,
    max_write_ms: f64,
    max_write_gap_ms: f64,
}
impl Default for Shared {
    fn default() -> Self {
        Self { status: "Bluetooth idle. Scan and select an X40 or Air vest.".into(), devices: vec![], scan: false, connect: None, quit: false, connected: false, frame: [0;40], deadline: Instant::now(), writes: 0, active_writes: 0, last_active_motors: 0, last_frame: [0;40], motor_mask: 0, frame_changes: 0, write_errors: 0, connections: 0, max_write_ms: 0.0, max_write_gap_ms: 0.0 }
    }
}
fn lock(shared: &Arc<Mutex<Shared>>) -> MutexGuard<'_, Shared> {
    shared.lock().unwrap_or_else(|e| e.into_inner())
}
fn supported(name: &str) -> bool {
    name == "TactSuitX40" || name.starts_with("TactSuitAirOnyx") || name.starts_with("TactSuitAirAsh")
}
fn fresh_frame(shared: &Shared, now: Instant) -> [u8;40] {
    if shared.connected && !shared.quit && now < shared.deadline { shared.frame } else { [0;40] }
}
fn scale_level(level: u8, intensity: f64) -> u8 {
    (level.min(15) as f64 * intensity.clamp(0.0, 1.0)).round() as u8
}

#[derive(GodotClass)]
#[class(base=RefCounted)]
struct FpsloppaBhapticsBle {
    base: Base<RefCounted>,
    shared: Arc<Mutex<Shared>>,
    worker: Option<JoinHandle<()>>,
}
#[godot_api]
impl IRefCounted for FpsloppaBhapticsBle {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base, shared: Arc::new(Mutex::new(Shared::default())), worker: None }
    }
}
impl FpsloppaBhapticsBle {
    fn ensure_worker(&mut self) {
        if self.worker.as_ref().is_some_and(|worker| !worker.is_finished()) { return; }
        if let Some(worker) = self.worker.take() { let _ = worker.join(); }
        { let mut state = lock(&self.shared); state.quit = false; state.connected = false; }
        let shared = self.shared.clone();
        self.worker = Some(thread::spawn(move || {
            // No Godot objects or engine API calls cross onto the Bluetooth thread.
            let result = std::panic::catch_unwind(|| {
                tokio::runtime::Builder::new_current_thread().enable_all().build()
                    .map_err(|e| e.to_string())?.block_on(worker_main(shared.clone()))
            });
            let mut state = lock(&shared);
            state.connected = false; state.frame = [0;40];
            state.status = match result {
                Ok(Ok(())) => "Bluetooth stopped.".into(),
                Ok(Err(error)) => format!("Bluetooth unavailable: {error}"),
                Err(_) => "Bluetooth worker failed; disable and scan again.".into(),
            };
        }));
    }
}
#[godot_api]
impl FpsloppaBhapticsBle {
    #[func]
    fn scan(&mut self) {
        self.ensure_worker();
        let mut state = lock(&self.shared);
        state.frame = [0;40]; state.deadline = Instant::now(); state.scan = true;
        state.status = "Scanning for X40 / Air vests…".into();
    }
    #[func]
    fn connect_device(&mut self, id: GString) -> bool {
        let id = id.to_string();
        if !lock(&self.shared).devices.iter().any(|d| d.id == id) { return false; }
        self.ensure_worker();
        let mut state = lock(&self.shared);
        state.frame = [0;40]; state.deadline = Instant::now(); state.connect = Some(id);
        state.connected = false; state.status = "Connecting to the selected vest…".into(); true
    }
    #[func]
    fn submit_frame(&self, values: PackedByteArray, intensity: f64) -> bool {
        if values.len() != 40 || !intensity.is_finite() { return false; }
        let mut state = lock(&self.shared);
        if !state.connected || state.quit { return false; }
        let strength = (intensity.clamp(0.0, 1.0) * 15.0).round() as u8;
        for (target, value) in state.frame.iter_mut().zip(values.as_slice()) { *target = if *value == 0 {0} else {strength}; }
        state.deadline = Instant::now() + FRAME_TTL; true
    }
    #[func]
    fn submit_levels(&self, values: PackedByteArray, intensity: f64) -> bool {
        if values.len() != 40 || !intensity.is_finite() { return false; }
        let mut state = lock(&self.shared);
        if !state.connected || state.quit { return false; }
        for (target, value) in state.frame.iter_mut().zip(values.as_slice()) { *target = scale_level(*value, intensity); }
        state.deadline = Instant::now() + FRAME_TTL; true
    }
    #[func]
    fn stop(&self) {
        let mut state = lock(&self.shared); state.frame = [0;40]; state.deadline = Instant::now();
    }
    #[func]
    fn close(&self) {
        let mut state = lock(&self.shared); state.quit = true; state.frame = [0;40]; state.deadline = Instant::now(); state.connected = false;
    }
    #[func]
    fn status_text(&self) -> GString { GString::from(lock(&self.shared).status.as_str()) }
    #[func]
    fn device_connected(&self) -> bool { lock(&self.shared).connected }
    #[func]
    fn is_running(&self) -> bool { self.worker.as_ref().is_some_and(|worker| !worker.is_finished()) }
    #[func]
    fn devices_json(&self) -> GString {
        let devices: Vec<_> = lock(&self.shared).devices.iter().map(|d| serde_json::json!({"id":d.id,"name":d.name})).collect();
        GString::from(&serde_json::to_string(&devices).unwrap_or_else(|_| "[]".into()))
    }
    #[func]
    fn diagnostics_json(&self) -> GString {
        let state = lock(&self.shared);
        // These count successful host writes, not device acknowledgements (BLE write-without-response).
        GString::from(&serde_json::json!({"writes":state.writes,"active_writes":state.active_writes,"last_active_motors":state.last_active_motors,"last_frame":state.last_frame.to_vec(),"motor_mask":state.motor_mask,"frame_changes":state.frame_changes,"write_errors":state.write_errors,"connections":state.connections,"max_write_ms":state.max_write_ms,"max_write_gap_ms":state.max_write_gap_ms}).to_string())
    }
}
impl Drop for FpsloppaBhapticsBle {
    fn drop(&mut self) {
        self.close();
        // All platform operations are timed out; never leave a worker using an unloaded library.
        if let Some(worker) = self.worker.take() { let _ = worker.join(); }
    }
}

async fn limited<T, E: std::fmt::Display>(future: impl Future<Output=Result<T,E>>) -> Result<T,String> {
    tokio::time::timeout(Duration::from_millis(1500), future).await
        .map_err(|_| "Bluetooth operation timed out".to_string())?.map_err(|e| e.to_string())
}
struct Session { peripheral: Peripheral, device: BHapticsDevice }
async fn release(session: &Session) {
    let _ = limited(session.device.send_vest_motor_frame(&VestMotorFrame { values: [0;40] })).await;
}
async fn disconnect(session: Session) {
    release(&session).await;
    let _ = limited(session.peripheral.disconnect()).await;
}
async fn scan(adapter: &Adapter, shared: &Arc<Mutex<Shared>>) -> Result<Vec<Peripheral>,String> {
    limited(adapter.start_scan(ScanFilter::default())).await?;
    for _ in 0..40 {
        if lock(shared).quit { break; }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
    let stopped = limited(adapter.stop_scan()).await;
    stopped?;
    limited(adapter.peripherals()).await
}
async fn connect(peripheral: Peripheral) -> Result<Session,String> {
    let result = async {
        limited(peripheral.connect()).await?;
        limited(peripheral.discover_services()).await?;
        let name = limited(peripheral.properties()).await?.and_then(|p| p.local_name)
            .ok_or("Device has no model name")?;
        if !supported(&name) { return Err("Unsupported vest model".into()); }
        if !peripheral.characteristics().iter().any(|c| c.uuid.to_string() == MOTOR_UUID) {
            return Err("Vest lacks the supported motor characteristic".into());
        }
        let device = limited(BHapticsDevice::new(peripheral.clone())).await?;
        if device.mappings().is_empty() { return Err("Vest has no validated motor mapping".into()); }
        // Start from zero, including after reconnect. Do not replay frames queued during discovery.
        limited(device.send_vest_motor_frame(&VestMotorFrame {values:[0;40]})).await?;
        Ok(Session { peripheral: peripheral.clone(), device })
    }.await;
    if result.is_err() { let _ = limited(peripheral.disconnect()).await; }
    result
}
fn map_frame(frame: &[u8;40], mappings: &[Arc<Mapping>]) -> VestMotorFrame {
    let mut values = [0u8;40];
    for mapping in mappings {
        let offset = match mapping.point { AttachmentPoint::TorsoFront => 0, AttachmentPoint::TorsoBack => 20, _ => continue };
        let rows = mapping.rows();
        if rows == 0 { continue; }
        // Resample the five-row logical vest onto Air's four rows without dropping bottom-row events.
        for row in 0..5 {
            let target_row = row * rows / 5;
            for column in 0..4 {
                if let Some(Some(index)) = mapping.actuators.get(target_row).and_then(|r| r.get(column)) {
                    if let Some(value) = values.get_mut(*index) { *value = (*value).max(frame[offset+row*4+column].min(15)); }
                }
            }
        }
    }
    VestMotorFrame { values }
}
async fn worker_main(shared: Arc<Mutex<Shared>>) -> Result<(),String> {
    #[cfg(target_os = "android")]
    if !ANDROID_READY.load(std::sync::atomic::Ordering::Acquire) {
        return Err("Android Bluetooth plugin has not been initialized".into());
    }
    // btleplug calls JavaVM.get_env(), which requires an already attached thread.
    // Keep the attachment alive through scan, writes and bounded disconnect.
    #[cfg(target_os = "android")]
    let _jni_attachment = ANDROID_VM.get().ok_or("Android Java VM is unavailable")?
        .attach_current_thread().map_err(|e| format!("Android worker attachment failed: {e}"))?;
    let manager = limited(Manager::new()).await?;
    let adapter = limited(manager.adapters()).await?.into_iter().next().ok_or("No Bluetooth adapter found")?;
    let mut peripherals: Vec<Peripheral> = vec![];
    let mut session: Option<Session> = None;
    let mut previous_write: Option<Instant> = None;
    loop {
        let (quit, do_scan, target) = {
            let mut state = lock(&shared);
            (state.quit, std::mem::take(&mut state.scan), state.connect.take())
        };
        if quit { break; }
        if do_scan {
            if let Some(old) = session.take() { disconnect(old).await; }
            lock(&shared).connected = false;
            match scan(&adapter, &shared).await {
                Ok(found) => {
                    peripherals.clear(); let mut devices = vec![];
                    for peripheral in found {
                        if lock(&shared).quit { break; }
                        if let Ok(Some(properties)) = limited(peripheral.properties()).await {
                            if let Some(name) = properties.local_name.filter(|n| supported(n)) {
                                devices.push(DeviceInfo { id: peripheral.id().to_string(), name });
                                peripherals.push(peripheral);
                            }
                        }
                    }
                    let mut state = lock(&shared);
                    state.status = if devices.is_empty() { "No supported vest found. Power on an X40 or Air and scan again.".into() } else { "Scan complete. Select a vest and connect.".into() };
                    state.devices = devices;
                }
                Err(error) => lock(&shared).status = format!("Scan failed: {error}"),
            }
        }
        if let Some(target) = target {
            if let Some(old) = session.take() { disconnect(old).await; }
            if let Some(peripheral) = peripherals.iter().find(|p| p.id().to_string() == target) {
                match connect(peripheral.clone()).await {
                    Ok(connected) => {
                        let mut state = lock(&shared);
                        state.status = format!("Connected directly to {}", connected.device.name());
                        state.frame = [0;40]; state.deadline = Instant::now(); state.connected = !state.quit;
                        state.connections += 1;
                        previous_write = None;
                        session = Some(connected);
                    }
                    Err(error) => { let mut state=lock(&shared); state.connected=false; state.status=format!("Connection failed: {error}"); }
                }
            } else {
                let mut state=lock(&shared);state.connected=false;state.status="Selected device is no longer available. Scan again.".into();
            }
        }
        if let Some(connected) = &session {
            let frame = fresh_frame(&lock(&shared), Instant::now());
            let frame = map_frame(&frame, connected.device.mappings());
            let write_started = Instant::now();
            if let Err(error) = limited(connected.device.send_vest_motor_frame(&frame)).await {
                let mut state = lock(&shared); state.connected = false; state.frame=[0;40]; state.status=format!("Vest disconnected: {error}. Scan and reconnect.");
                state.write_errors += 1;
                drop(state);
                if let Some(old) = session.take() { disconnect(old).await; }
            } else {
                let mut state = lock(&shared);
                let now = Instant::now();
                state.max_write_ms = state.max_write_ms.max(now.duration_since(write_started).as_secs_f64()*1000.0);
                if let Some(previous) = previous_write { state.max_write_gap_ms = state.max_write_gap_ms.max(now.duration_since(previous).as_secs_f64()*1000.0); }
                previous_write = Some(now);
                if state.last_frame != frame.values { state.frame_changes += 1; }
                state.last_frame = frame.values;
                for (index, value) in frame.values.iter().enumerate() { if *value > 0 { state.motor_mask |= 1u64 << index; } }
                state.writes += 1;
                state.last_active_motors = frame.values.iter().filter(|v| **v > 0).count();
                if state.last_active_motors > 0 { state.active_writes += 1; }
            }
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    if let Some(old) = session { disconnect(old).await; }
    Ok(())
}

struct BhapticsExtension;
#[gdextension]
unsafe impl ExtensionLibrary for BhapticsExtension {}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn profile_levels_preserve_gradients_and_global_strength_cap() {
        assert_eq!(scale_level(15,0.25),4);
        assert_eq!(scale_level(8,0.25),2);
        assert_eq!(scale_level(4,0.25),1);
        assert_eq!(scale_level(255,0.25),4);
        assert_eq!(scale_level(15,0.0),0);
    }
    #[test]
    fn unverified_models_are_not_selected() {
        assert!(supported("TactSuitX40")); assert!(supported("TactSuitAirOnyx"));
        assert!(!supported("TactSuitPro")); assert!(!supported("Unknown")); assert!(!supported("TactSuitX16"));
    }
    #[test]
    fn watchdog_releases_expired_and_disconnected_frames() {
        let now=Instant::now();
        let mut state=Shared { connected:true, frame:[15;40], deadline:now+FRAME_TTL, ..Shared::default() };
        assert_eq!(fresh_frame(&state,now),[15;40]); assert_eq!(fresh_frame(&state,now+FRAME_TTL),[0;40]);
        state.connected=false; assert_eq!(fresh_frame(&state,now),[0;40]);
        state.connected=true;state.quit=true;assert_eq!(fresh_frame(&state,now),[0;40]);
    }
    #[test]
    fn air_resampling_preserves_bottom_rows_and_caps_strength() {
        let mapping=Arc::new(Mapping {point:AttachmentPoint::TorsoFront, wrapping:false, legacy:false, actuators:(0..4).map(|r|(0..4).map(|c|Some(r*4+c)).collect()).collect()});
        let mut frame=[0;40];frame[16]=255;frame[0]=4;frame[4]=8;
        let raw=map_frame(&frame,&[mapping]);
        assert_eq!(raw.values[12],15);assert_eq!(raw.values[0],8);assert_eq!(raw.values[20],0);
        assert_eq!(raw.encode()[6],0xf0);
    }
    #[test]
    fn native_motor_frame_has_known_packed_wire_format() {
        let mut values=[0;40];values[0]=4;values[1]=9;values[39]=15;
        let bytes=VestMotorFrame{values}.encode();assert_eq!(bytes.len(),20);assert_eq!(bytes[0],0x49);assert_eq!(bytes[19],0x0f);
    }
}
