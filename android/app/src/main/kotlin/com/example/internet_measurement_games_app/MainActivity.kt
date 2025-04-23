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
                    "-server.url",
                    "ws://msak-mlab2-lax06.mlab-oti.measurement-lab.org/throughput/v1/download?access_token=eyJhbGciOiJFZERTQSIsImtpZCI6ImxvY2F0ZV8yMDIwMDQwOSJ9.eyJhdWQiOlsibWxhYjItbGF4MDYubWxhYi1vdGkubWVhc3VyZW1lbnQtbGFiLm9yZyJdLCJleHAiOjE3NDUzODQ5NzQsImlzcyI6ImxvY2F0ZSIsImp0aSI6IjM5M2Q0MmRkLWY5NjMtNGY0Ni1hYTdlLWM1MDNjZmNhZmQ4OCIsInN1YiI6Im1zYWsifQ.5ZOviw8DIsC_QLtrJOaJKHWIXlhKMMPlKUexCMrxzxNZXZaeEd_XqmBovq7j0fjvUnKnTRIa_yRV__QwTqibAA&index=0&locate_version=v2&metro_rank=0"
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