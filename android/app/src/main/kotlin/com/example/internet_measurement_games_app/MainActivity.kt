package com.example.internet_measurement_games_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.io.File
import java.io.IOException
import java.io.InputStream
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "msak_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "runMsak") {
                val output = runMsakBinary()
                result.success(output)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun runMsakBinary(): String {
        val libDir = applicationInfo.nativeLibraryDir  // e.g. /data/app/..../lib/arm64
        val binaryPath = "$libDir/libminimal-download.so"
        try{
            val process = ProcessBuilder()
                .command(
                    binaryPath,
                    "-duration", "1s",
                    )
                .redirectErrorStream(true)
                .start()
            return process.inputStream.bufferedReader().use { it.readText() }
        }
        catch (e: Exception) {
            Log.e("MSAK", "Error running binary", e)
            return "ERROR: ${e.message}"
        }
    }

}