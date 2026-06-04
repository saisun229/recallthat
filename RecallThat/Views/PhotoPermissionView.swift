import SwiftUI
@preconcurrency import Photos

struct PhotoPermissionView: View {
    let status: PHAuthorizationStatus
    let onRequestAccess: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "photo.on.rectangle.angled")
        } description: {
            Text(description)
        } actions: {
            if status == .denied || status == .restricted {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            } else if status == .notDetermined {
                Button("Allow Access") {
                    onRequestAccess()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var title: String {
        switch status {
        case .denied, .restricted: return "Photos Access Denied"
        case .limited:             return "Limited Photos Access"
        default:                   return "Allow Photos Access"
        }
    }

    private var description: String {
        switch status {
        case .denied, .restricted:
            return "RecallThat needs access to your photos to find screenshots. Go to Settings → Privacy → Photos to allow access."
        case .limited:
            return "You've granted limited access. Go to Settings → Privacy → Photos to allow full access to all screenshots."
        default:
            return "RecallThat needs access to your Photos library to find and index your screenshots. Everything stays on your device — nothing is uploaded."
        }
    }
}
