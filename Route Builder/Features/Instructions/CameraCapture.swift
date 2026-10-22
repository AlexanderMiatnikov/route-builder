import SwiftUI
import UIKit

struct CameraCapture: UIViewControllerRepresentable {
    enum Source {
        case camera
        case library
    }

    let source: Source
    let onImage: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cameraCapabilities) private var capabilities

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        let availableCamera = capabilities.isSourceAvailable(.camera)
        switch source {
        case .camera where availableCamera:
            picker.sourceType = .camera
        default:
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapture
        init(parent: CameraCapture) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImage(nil)
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.originalImage] as? UIImage)
            let data = image?.jpegData(compressionQuality: parent.capabilities.jpegQuality)
            parent.onImage(data)
            parent.dismiss()
        }
    }
}
