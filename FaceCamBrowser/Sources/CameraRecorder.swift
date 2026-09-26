import AVFoundation
import Photos

/// Owns the front-camera capture session and records movie files that are saved to Photos.
final class CameraRecorder: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var statusMessage: String?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "facecam.session")
    private var isConfigured = false
    private var timer: Timer?
    private var recordingStart: Date?

    // MARK: - Session lifecycle

    func start() {
        Task {
            let videoOK = await AVCaptureDevice.requestAccess(for: .video)
            let audioOK = await AVCaptureDevice.requestAccess(for: .audio)
            guard videoOK else {
                post("Camera access denied. Enable it in Settings > Privacy > Camera.")
                return
            }
            sessionQueue.async {
                if !self.isConfigured { self.configure(withAudio: audioOK) }
                if !self.session.isRunning { self.session.startRunning() }
                let running = self.session.isRunning
                DispatchQueue.main.async { self.isRunning = running }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configure(withAudio: Bool) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else {
            post("Front camera unavailable.")
            return
        }
        session.addInput(videoInput)

        if withAudio {
            // Configure the audio session ourselves so web page audio keeps playing while the mic records.
            session.automaticallyConfiguresApplicationAudioSession = false
            let audio = AVAudioSession.sharedInstance()
            try? audio.setCategory(.playAndRecord,
                                   mode: .videoRecording,
                                   options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try? audio.setActive(true)

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        guard session.canAddOutput(movieOutput) else {
            post("Cannot record video on this device.")
            return
        }
        session.addOutput(movieOutput)

        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90 // portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true // match the selfie preview
            }
            if movieOutput.availableVideoCodecTypes.contains(.hevc) {
                movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
            }
        }

        isConfigured = true
    }

    // MARK: - Recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        sessionQueue.async {
            guard self.session.isRunning, !self.movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("facecam-\(UUID().uuidString)")
                .appendingPathExtension("mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        sessionQueue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
        }
    }

    private func startTimer() {
        recordingStart = Date()
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStart else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStart = nil
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                self.post("Photos access denied. Enable it in Settings > Privacy > Photos to save recordings.")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                try? FileManager.default.removeItem(at: url)
                self.post(success ? "Saved to Photos." : "Save failed: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    private func post(_ message: String) {
        DispatchQueue.main.async { self.statusMessage = message }
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.isRecording = true
            self.startTimer()
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimer()
        }

        // Interruptions (e.g. leaving the app) report an error but usually still finalize a playable file.
        var finished = error == nil
        if let nsError = error as NSError?,
           let ok = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool {
            finished = ok
        }

        if finished {
            saveToPhotos(outputFileURL)
        } else {
            try? FileManager.default.removeItem(at: outputFileURL)
            post("Recording failed: \(error?.localizedDescription ?? "unknown error")")
        }
    }
}
