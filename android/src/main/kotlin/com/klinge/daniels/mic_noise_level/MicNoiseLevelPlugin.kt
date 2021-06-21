package com.klinge.daniels.mic_noise_level

import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import java.util.Timer
import java.util.TimerTask

private const val MAX_AMPLITUDE = 32767
private const val EVENT_CHANNEL_NAME = "mic_noise_level.eventChannel"
private const val SAMPLE_RATE = 44100

/** MicNoiseLevelPlugin */
class MicNoiseLevelPlugin: FlutterPlugin, RequestPermissionsResultListener, EventChannel.StreamHandler, ActivityAware {

  private var _timer: Timer? = null

  private var eventSink: EventSink? = null
  private var recorder: MediaRecorder? = null

  private var currentActivity: Activity? = null

  //----------------------------------------------------------------------------
  // Life cycle
  //----------------------------------------------------------------------------

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val messenger = flutterPluginBinding.getFlutterEngine().getDartExecutor()
    val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    eventChannel.setStreamHandler(MicNoiseLevelPlugin())
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
  }

  override fun onDetachedFromActivity() {
    currentActivity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    currentActivity = null
  }


  /// Called from Flutter, starts the stream
  override fun onListen(arguments: Any?, events: EventSink?) {
    this._timer = Timer()
    this.eventSink = events
    initAudioRecorder()
  }


  /// Called from Flutter, cancels the stream
  override fun onCancel(arguments: Any?) {
    this._timer?.cancel()
    // this._timer?.purge()
    // this._timer = null
    // this.eventSink = null
    // this.recorder?.stop()
    // this.recorder?.release()
    // this.recorder = null
  }

  //----------------------------------------------------------------------------
  // Permission
  //----------------------------------------------------------------------------

  /// Called by the plugin itself whenever it detects that permissions have not been granted.
  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
    val requestAudioPermissionCode = 200

    when (requestCode) {
      requestAudioPermissionCode -> if (grantResults[0] == PackageManager.PERMISSION_GRANTED) return true
    }

    return false
  }

  private fun initAudioRecorder() {
    this.recorder = MediaRecorder()
      this.recorder?.setAudioSource(MediaRecorder.AudioSource.MIC)
      this.recorder?.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
      this.recorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
      this.recorder?.setAudioSamplingRate(SAMPLE_RATE)
      this.recorder?.setAudioChannels(1)
      this.recorder?.setOutputFile("/dev/null")
      this.recorder?.prepare()
      this.recorder?.start()

      this._timer?.schedule(MaxAmplitudeTask(this.recorder, this.eventSink), 0, 10)
  }
}

internal class MaxAmplitudeTask(private val recorder: MediaRecorder?, private val eventSink: EventSink?) : TimerTask() {

  var prevAmplitude: Int = 0

  override fun run() {
    Handler(Looper.getMainLooper()).post {      
      var maxAmplitude = this.recorder?.maxAmplitude

      if(maxAmplitude !== null) {
        if(maxAmplitude == 0) {
          maxAmplitude = prevAmplitude
        }

        prevAmplitude = maxAmplitude

        val normalizedAmplitude = maxAmplitude.toDouble() / MAX_AMPLITUDE.toDouble()
        val db = 20 * Math.log10(normalizedAmplitude)

        eventSink!!.success(db)
      }
    }
  }
}
