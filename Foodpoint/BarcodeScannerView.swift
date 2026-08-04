import SwiftUI
import VisionKit
internal import Vision

struct BarcodeScannerView: UIViewControllerRepresentable {
    // Callback closure instead of @Binding
    var onScan: (String) -> Void
    
    var recognizedItems: Set<DataScannerViewController.RecognizedDataType> = [
        .barcode(symbologies: [.ean8, .ean13, .upce])
    ]

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedItems,
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Simple start check: only start if it isn't scanning yet
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: BarcodeScannerView
        private var hasScanned = false // Local flag to prevent double-callbacks

        init(parent: BarcodeScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned, let item = addedItems.first else { return }
            processItem(item, scanner: dataScanner)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !hasScanned else { return }
            processItem(item, scanner: dataScanner)
        }

        private func processItem(_ item: RecognizedItem, scanner: DataScannerViewController) {
            switch item {
            case .barcode(let barcode):
                let payload = barcode.payloadStringValue ?? barcode.observation.payloadStringValue
                
                if let payload = payload {
                    hasScanned = true
                    scanner.stopScanning()
                    
                    // Fire the callback cleanly on the main thread
                    DispatchQueue.main.async {
                        self.parent.onScan(payload)
                    }
                }
            default:
                break
            }
        }
    }
}
