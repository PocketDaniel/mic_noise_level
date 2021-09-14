import Flutter
import UIKit
import AVFoundation

//---------------------------------------------------------------------------------

public class SwiftMicNoiseLevelPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    var audioRecorder = AVAudioRecorder()

    private var timer: Timer?

    //---------------------------------------------------------------------------------
    // Plugin registration
    //---------------------------------------------------------------------------------
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftMicNoiseLevelPlugin()

        let eventChannel = FlutterEventChannel.init(name: "mic_noise_level.eventChannel", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
        instance.setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc func handleInterruption(notification: Notification) {
        if let _eventSink = eventSink {
            _eventSink(FlutterError(code: "100", message: "Recording was interrupted", details: "Another process interrupted recording."))
        }
    }
    
    //---------------------------------------------------------------------------------
    // Channel events
    //---------------------------------------------------------------------------------

    public func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = eventSink
        initAudioRecorder()
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        timer?.invalidate()
        audioRecorder.stop()
        return nil
    }
    
    //---------------------------------------------------------------------------------
    // Stream handlers
    //---------------------------------------------------------------------------------

    // Handle stream - Swift => Flutter
    private func emitValue(_ value: Float) {
        if (eventSink == nil) {
            return
        }

        eventSink!(value)
    }
    
    func initAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        if audioSession.recordPermission != .granted {
            audioSession.requestRecordPermission { (isGranted) in
                if !isGranted {
                    fatalError("You must allow audio recording for this plugin to work")
                }
            }
        }
        
        let url = URL(fileURLWithPath: "/dev/null", isDirectory: true)
        let recorderSettings: [String:Any] = [
            AVFormatIDKey: NSNumber(value: kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: recorderSettings)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            
            startMeasuring()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func startMeasuring() {
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { (timer) in
            self.audioRecorder.updateMeters()
            self.emitValue(self.audioRecorder.averagePower(forChannel: 0))
        })
    }
}
