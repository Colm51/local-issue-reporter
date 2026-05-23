import SwiftUI
import UIKit

// SwiftUI does not have a built-in camera view. UIViewControllerRepresentable
// lets this app show UIKit's UIImagePickerController inside SwiftUI.
struct PhotoPicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary

        var uiImagePickerSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .photoLibrary:
                return .photoLibrary
            }
        }
    }

    let source: Source

    // @Binding lets PhotoPicker add the chosen image back into ContentView state.
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        // The coordinator receives UIKit delegate callbacks and passes results to SwiftUI.
        Coordinator(photoPicker: self)
    }

    // Creates the UIKit image picker used by SwiftUI. UIImagePickerController handles
    // both camera capture and photo library selection depending on the source value.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = source.uiImagePickerSourceType
        imagePickerController.delegate = context.coordinator
        return imagePickerController
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let photoPicker: PhotoPicker

        init(photoPicker: PhotoPicker) {
            self.photoPicker = photoPicker
        }

        // Called after the user takes a photo or chooses one from the library.
        // The picked UIImage is copied into SwiftUI state, then the picker closes.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let selectedImage = info[.originalImage] as? UIImage {
                photoPicker.selectedImages.append(selectedImage)
            }

            photoPicker.dismiss()
        }

        // Called when the user cancels the camera or library screen.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            photoPicker.dismiss()
        }
    }
}
