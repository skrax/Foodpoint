import SwiftUI
import AVFoundation

struct FastFoodBarcodeScanner: UIViewRepresentable {
    var onScan: (String) -> Void

    func makeUIView(context: Context) -> FastScannerUIView {
        let view = FastScannerUIView()
        view.onScan = onScan
        return view
    }

    func updateUIView(_ uiView: FastScannerUIView, context: Context) {}
}

// Low-level UIKit view wrapped directly around AVCaptureSession
final class FastScannerUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure preview fills full view bounds seamlessly
        previewLayer?.frame = bounds
    }

    private func setupCamera() {
        captureSession.beginConfiguration()

        // High quality preset for crisp macro focus on food packages
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                captureSession.commitConfiguration()
                return
            }

        do {
            try videoDevice.lockForConfiguration()
            
            // Continuous auto-focus for scanning small/close barcodes
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            
            // Automatically adjust focus when the phone moves to a new item
            if videoDevice.isSubjectAreaChangeMonitoringEnabled {
                videoDevice.isSubjectAreaChangeMonitoringEnabled = true
            }
            
            // Enable low-light boost if available (helpful for pantry/fridge scanning)
            if videoDevice.isLowLightBoostSupported {
                videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("⚠️ Failed to lock camera device for configuration: \(error)")
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // 🛒 Hardware-level filter: ONLY food barcode formats
            metadataOutput.metadataObjectTypes = [
                .ean13,
                .upce,
                .ean8
            ]
        }

        captureSession.commitConfiguration()

        // Hardware accelerated video preview layer
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
        self.previewLayer = preview

        // Start session on background thread to keep UI smooth
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    // Direct hardware delegate callback - fires instantly upon detection
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasScanned = true
        
        // Haptic tap feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Stop session cleanly
        captureSession.stopRunning()
        
        onScan?(stringValue)
    }
}
