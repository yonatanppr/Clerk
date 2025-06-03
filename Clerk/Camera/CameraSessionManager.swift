import AVFoundation
import Combine

final class CameraSessionManager: NSObject {
    // Core AVFoundation objects
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var isTorchOn = false
    let framePublisher = PassthroughSubject<CMSampleBuffer, Never>()


    // A Combine PassthroughSubject or delegate pattern to emit each CMSampleBuffer
    // e.g. let framePublisher = PassthroughSubject<CMSampleBuffer, Never>()
    
    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        // 1. Find and add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back),
              let deviceInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(deviceInput) else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo  // high res stills + adequate video
        session.addInput(deviceInput)

        // 2. Video Output for live frames (for edge detection)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoFrameQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoOrientation = .portrait
        }

        // 3. Photo Output for high-res still capture
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if isTorchOn {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            }
            device.unlockForConfiguration()
        } catch {
            // Handle errors minimally (e.g. ignore or send a published error)
        }
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isTorchOn ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureProcessor(completion: completion))
    }
}

// Conform to AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        framePublisher.send(sampleBuffer)
    }
}

// Helper: A separate class to handle AVCapturePhotoCaptureDelegate callbacks
private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        }
    }
}
