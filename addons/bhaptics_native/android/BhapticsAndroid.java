package org.fpsloppa.bhaptics;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import java.util.Collections;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Permission and class-loader bootstrap only. The Rust worker owns vest I/O. */
public final class BhapticsAndroid extends GodotPlugin {
    private static final int PERMISSION_REQUEST = 48041;
    private static native boolean nativeInitialize();
    private final AtomicBoolean requesting = new AtomicBoolean(false);
    private volatile String status = "Tap Scan to allow Bluetooth access.";
    private volatile boolean initialized;
    private boolean initializationAttempted;

    public BhapticsAndroid(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "FpsloppaBhapticsAndroid"; }
    @Override public Set<String> getPluginGDExtensionLibrariesPaths() {
        return Collections.singleton("res://addons/bhaptics_native/bhaptics.gdextension");
    }
    private String[] permissions() {
        return Build.VERSION.SDK_INT >= 31
            ? new String[]{Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT}
            : new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
    }
    private boolean permissionsGranted(Activity activity) {
        for (String permission : permissions()) {
            if (activity.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) return false;
        }
        return true;
    }
    @UsedByGodot public String status_text() { return status; }
    @UsedByGodot public boolean prepare() {
        Activity activity = getActivity();
        if (activity == null) { status = "Android activity is unavailable."; return false; }
        if (!permissionsGranted(activity)) {
            status = "Allow Bluetooth access, then tap Scan again.";
            if (requesting.compareAndSet(false, true)) {
                activity.runOnUiThread(() -> {
                    if (activity.isFinishing()) { requesting.set(false); return; }
                    activity.requestPermissions(permissions(), PERMISSION_REQUEST);
                });
            }
            return false;
        }
        try {
            BluetoothManager manager = (BluetoothManager) activity.getSystemService(Context.BLUETOOTH_SERVICE);
            BluetoothAdapter adapter = manager == null ? null : manager.getAdapter();
            if (adapter == null) { status = "This device has no Bluetooth LE adapter."; return false; }
            if (!adapter.isEnabled()) { status = "Enable Bluetooth in Android settings, then scan again."; return false; }
            if (!initialized && !initializationAttempted) {
                System.loadLibrary("fpsloppa_bhaptics_native.android");
                // The JNI dependency uses process-wide caches; a partial failure
                // requires a fresh process rather than repeating initialization.
                initializationAttempted = true;
                initialized = nativeInitialize();
            }
            status = initialized ? "Bluetooth ready." : "Native Bluetooth initialization failed. Restart the game.";
            return initialized;
        } catch (LinkageError | RuntimeException failure) {
            status = "Bluetooth unavailable: " + failure.getClass().getSimpleName();
            return false;
        }
    }
    @Override public void onMainRequestPermissionsResult(int request, String[] names, int[] results) {
        if (request != PERMISSION_REQUEST) return;
        requesting.set(false);
        Activity activity = getActivity();
        status = activity != null && permissionsGranted(activity)
            ? "Bluetooth permission granted. Tap Scan again."
            : "Bluetooth permission denied. Grant it in app settings or tap Scan to retry.";
    }
}
