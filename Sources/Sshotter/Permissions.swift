import AppKit
import CoreGraphics

/// Screen Recording is the only system permission sShooter needs: capturing
/// the screen goes through ScreenCaptureKit.
enum Permission: Int, CaseIterable {
    case screenRecording

    var title: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        }
    }

    var isGranted: Bool {
        switch self {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        }
    }

    func request() {
        switch self {
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        }
    }

    var settingsURL: URL {
        switch self {
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        }
    }
}
