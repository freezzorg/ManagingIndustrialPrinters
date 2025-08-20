package kz.kcep.mip

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val SCAN_CHANNEL = "com.symbol.datawedge/scan"
    private var eventSink: EventChannel.EventSink? = null

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "android.intent.ACTION_DECODE_DATA") {
                intent.getStringExtra("barcode_string")?.let { 
                    eventSink?.success(it)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    registerReceiver(scanReceiver, IntentFilter("android.intent.ACTION_DECODE_DATA"))
                }

                override fun onCancel(arguments: Any?) {
                    unregisterReceiver(scanReceiver)
                    eventSink = null
                }
            }
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(scanReceiver)
        } catch (_: IllegalArgumentException) {}
    }
    
    override fun onResume() {
        super.onResume()
        try {
            sendBroadcast(Intent("com.urovo.scanwedge.ENABLE_SCANNER").apply {
                putExtra("enable", true)
            })
        } catch (_: Exception) {}
    }
}
