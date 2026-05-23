import CoreLocation
import MessageUI
import SwiftUI
import UIKit

struct ContentView: View {
    private let defaultDestinationEmailAddress = "reports@example.com"
    private let maximumPhotoCount = 3
    private let draftUserDefaultsKey = "draftReport"
    private let draftPhotosFolderName = "DraftPhotos"

    // @StateObject keeps one LocationManager alive while this view is on screen.
    @StateObject private var locationManager = LocationManager()
    @StateObject private var submittedReportStore = SubmittedReportStore()

    // @State values are simple pieces of screen data. When any of them changes,
    // SwiftUI redraws the parts of the view that use that value.
    @State private var isShowingReportForm = false
    @State private var selectedIssueType: IssueType = .pothole
    @State private var notes = ""
    @State private var destinationEmailAddress = "reports@example.com"
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotoSource: PhotoPicker.Source?
    @State private var reportEmail: ReportEmail?
    @State private var alertMessage: String?
    @State private var submissionSuccessMessage: String?
    @State private var hasSavedDraft = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Local Issue Reporter")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Report potholes, bike lane problems, and other local issues by email.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("New Report") {
                    startNewReport()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if hasSavedDraft {
                    Button("Continue Draft") {
                        continueDraft()
                    }
                    .buttonStyle(.bordered)

                    Button("Discard Draft", role: .destructive) {
                        discardDraft()
                    }
                    .buttonStyle(.bordered)
                }

                NavigationLink {
                    SubmittedReportsView(store: submittedReportStore)
                } label: {
                    Text("Submitted Reports")
                }
                .buttonStyle(.bordered)

                if let submissionSuccessMessage {
                    Text(submissionSuccessMessage)
                        .font(.callout)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .navigationTitle("Reports")
            // This sheet opens the report form after the user taps New Report.
            .sheet(isPresented: $isShowingReportForm) {
                reportForm
            }
            // Alerts are driven by alertMessage. If it has text, the alert appears.
            .alert("Local Issue Reporter", isPresented: alertIsPresented) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                // Ask early so the user can grant location before creating a report.
                locationManager.requestLocationPermission()
                refreshDraftStatus()
            }
            .onChange(of: locationManager.locationErrorMessage) { _, newValue in
                if let newValue {
                    alertMessage = newValue
                }
            }
        }
    }

    private var reportForm: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    Picker("Issue type", selection: $selectedIssueType) {
                        ForEach(IssueType.allCases) { issueType in
                            Text(issueType.rawValue).tag(issueType)
                        }
                    }

                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
                    Button("Take Photo") {
                        chooseCamera()
                    }
                    .disabled(selectedImages.count >= maximumPhotoCount)

                    Button("Choose From Photo Library") {
                        choosePhotoLibrary()
                    }
                    .disabled(selectedImages.count >= maximumPhotoCount)

                    if selectedImages.isEmpty {
                        Text("No photos selected")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedImages.count) of \(maximumPhotoCount) photos selected")
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                Section("Location") {
                    Button("Refresh Current Location") {
                        refreshCurrentLocation()
                    }

                    if let location = locationManager.latestLocation {
                        Text("Latitude: \(location.coordinate.latitude)")
                        Text("Longitude: \(location.coordinate.longitude)")
                    } else {
                        Text("Location not captured yet")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Email") {
                    TextField("Destination email", text: $destinationEmailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("Send Report") {
                        prepareAndShowMailComposer()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("New Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingReportForm = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Draft") {
                        saveDraft()
                    }
                }
            }
            // These sheets are attached to the report form because the form is
            // already presented as a sheet. Presenting from the visible view keeps
            // the camera, library, and mail composer responsive.
            .sheet(item: $selectedPhotoSource) { source in
                PhotoPicker(source: source, selectedImages: $selectedImages)
            }
            .sheet(item: $reportEmail) { report in
                MailComposeView(report: report) { result in
                    finishReport(result: result, report: report)
                }
            }
            // The form also needs its own alert because validation happens here.
            .alert("Local Issue Reporter", isPresented: alertIsPresented) {
                Button("OK", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // SwiftUI alerts need a Binding<Bool>. This converts the optional alert text
    // into true when there is a message and false when the message is cleared.
    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue {
                    alertMessage = nil
                }
            }
        )
    }

    // Resets the form and asks Core Location for a fresh one-time coordinate.
    private func startNewReport() {
        selectedIssueType = .pothole
        notes = ""
        destinationEmailAddress = defaultDestinationEmailAddress
        selectedImages = []
        locationManager.requestCurrentLocation()
        isShowingReportForm = true
    }

    // Checks whether the camera exists before opening it. The iOS Simulator usually
    // has no camera, so this prevents the app from showing a broken camera screen.
    private func chooseCamera() {
        guard selectedImages.count < maximumPhotoCount else {
            alertMessage = "You can attach up to \(maximumPhotoCount) photos."
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertMessage = "Camera is not available on this device."
            return
        }

        // Setting this value triggers the PhotoPicker sheet.
        selectedPhotoSource = .camera
    }

    // Checks whether the photo library can be opened before presenting the picker.
    private func choosePhotoLibrary() {
        guard selectedImages.count < maximumPhotoCount else {
            alertMessage = "You can attach up to \(maximumPhotoCount) photos."
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            alertMessage = "Photo library is not available on this device."
            return
        }

        // Setting this value triggers the PhotoPicker sheet.
        selectedPhotoSource = .photoLibrary
    }

    // Requests the current location and immediately shows any synchronous
    // availability or permission error created by LocationManager.
    private func refreshCurrentLocation() {
        locationManager.requestCurrentLocation()

        if let locationErrorMessage = locationManager.locationErrorMessage {
            alertMessage = locationErrorMessage
        }
    }

    // Validates the report, builds the email subject/body, and opens the native
    // mail compose sheet. MFMailComposeViewController only works when the device
    // has Mail configured with at least one account.
    private func prepareAndShowMailComposer() {
        guard MFMailComposeViewController.canSendMail() else {
            alertMessage = "Mail is not available. Configure the Mail app on this device and try again."
            return
        }

        guard !selectedImages.isEmpty else {
            alertMessage = "Please take or choose at least one photo before sending the report."
            return
        }

        guard let location = locationManager.latestLocation else {
            alertMessage = "Location is not available yet. Refresh location or check permission settings."
            return
        }

        let trimmedDestinationEmailAddress = destinationEmailAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDestinationEmailAddress.isEmpty else {
            alertMessage = "Enter a destination email address."
            return
        }

        // Setting reportEmail triggers the MailComposeView sheet.
        reportEmail = ReportEmail(
            reportID: Self.makeReportID(),
            destinationEmailAddress: trimmedDestinationEmailAddress,
            issueType: selectedIssueType,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date(),
            photos: selectedImages
        )
    }

    // Called after the native Mail compose sheet finishes. Returning to the main
    // screen makes it clear that the report flow is complete.
    private func finishReport(result: MFMailComposeResult, report: ReportEmail) {
        print("LocalIssueReporter debug: Mail compose finished with result: \(result)")

        if result == .sent {
            submittedReportStore.add(SubmittedReport(report: report))
        } else {
            print("LocalIssueReporter debug: Report history not saved because result was not .sent.")
        }

        reportEmail = nil
        isShowingReportForm = false

        if result == .sent {
            deleteDraft()
            submissionSuccessMessage = "Report Successfully Submitted"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                submissionSuccessMessage = nil
            }
        }
    }

    private static func makeReportID() -> String {
        String(UUID().uuidString.prefix(6)).uppercased()
    }

    private func saveDraft() {
        guard let location = locationManager.latestLocation else {
            alertMessage = "Location is not available yet. Refresh location or check permission settings."
            return
        }

        if let existingDraft = loadDraft() {
            deleteDraftPhotoFiles(fileNames: existingDraft.photoFileNames)
        }

        let photoFileNames = saveDraftPhotos()

        guard photoFileNames.count == selectedImages.count else {
            deleteDraftPhotoFiles(fileNames: photoFileNames)
            alertMessage = "Could not save draft photos. Try again."
            return
        }

        let draft = DraftReport(
            issueType: selectedIssueType.rawValue,
            notes: notes,
            destinationEmailAddress: destinationEmailAddress,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            photoFileNames: photoFileNames,
            savedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(draft) else {
            deleteDraftPhotoFiles(fileNames: photoFileNames)
            alertMessage = "Could not save draft. Try again."
            return
        }

        UserDefaults.standard.set(data, forKey: draftUserDefaultsKey)
        hasSavedDraft = true
        isShowingReportForm = false
        showTemporaryMessage("Draft Saved")
    }

    private func continueDraft() {
        guard let draft = loadDraft() else {
            hasSavedDraft = false
            return
        }

        selectedIssueType = IssueType(rawValue: draft.issueType) ?? .pothole
        notes = draft.notes
        destinationEmailAddress = draft.destinationEmailAddress
        locationManager.latestLocation = CLLocation(latitude: draft.latitude, longitude: draft.longitude)

        let restoredImages = loadDraftPhotos(fileNames: draft.photoFileNames)
        selectedImages = restoredImages

        if restoredImages.count < draft.photoFileNames.count {
            showTemporaryMessage("Some draft photos could not be restored")
        }

        isShowingReportForm = true
    }

    private func discardDraft() {
        deleteDraft()
    }

    private func refreshDraftStatus() {
        hasSavedDraft = loadDraft() != nil
    }

    private func loadDraft() -> DraftReport? {
        guard let data = UserDefaults.standard.data(forKey: draftUserDefaultsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(DraftReport.self, from: data)
    }

    private func deleteDraft() {
        if let draft = loadDraft() {
            deleteDraftPhotoFiles(fileNames: draft.photoFileNames)
        }

        UserDefaults.standard.removeObject(forKey: draftUserDefaultsKey)
        hasSavedDraft = false
    }

    private func saveDraftPhotos() -> [String] {
        guard let directoryURL = draftPhotosDirectory() else {
            return []
        }

        var fileNames: [String] = []

        for image in selectedImages {
            let fileName = "draft-photo-\(UUID().uuidString).jpg"
            let fileURL = directoryURL.appendingPathComponent(fileName)
            let resizedImage = resizedDraftImage(image)

            guard let data = resizedImage.jpegData(compressionQuality: 0.75) else {
                continue
            }

            do {
                try data.write(to: fileURL, options: .atomic)
                fileNames.append(fileName)
            } catch {
                print("LocalIssueReporter debug: Could not save draft photo: \(error.localizedDescription)")
            }
        }

        return fileNames
    }

    private func loadDraftPhotos(fileNames: [String]) -> [UIImage] {
        guard let directoryURL = draftPhotosDirectory() else {
            return []
        }

        return fileNames.compactMap { fileName in
            let fileURL = directoryURL.appendingPathComponent(fileName)

            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }

            return UIImage(data: data)
        }
    }

    private func deleteDraftPhotoFiles(fileNames: [String]) {
        guard let directoryURL = draftPhotosDirectory() else {
            return
        }

        for fileName in fileNames {
            let fileURL = directoryURL.appendingPathComponent(fileName)

            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("LocalIssueReporter debug: Could not delete draft photo: \(error.localizedDescription)")
            }
        }
    }

    private func draftPhotosDirectory() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = documentsURL.appendingPathComponent(draftPhotosFolderName)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        } catch {
            print("LocalIssueReporter debug: Could not create draft photo folder: \(error.localizedDescription)")
            return nil
        }
    }

    private func resizedDraftImage(_ image: UIImage) -> UIImage {
        let maximumLongestEdge: CGFloat = 1600
        let longestEdge = max(image.size.width, image.size.height)

        guard longestEdge > maximumLongestEdge else {
            return image
        }

        let scale = maximumLongestEdge / longestEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func showTemporaryMessage(_ message: String) {
        submissionSuccessMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if submissionSuccessMessage == message {
                submissionSuccessMessage = nil
            }
        }
    }
}

// The sheet(item:) modifier requires the item type to have an id.
extension PhotoPicker.Source: Identifiable {
    var id: String {
        switch self {
        case .camera:
            return "camera"
        case .photoLibrary:
            return "photoLibrary"
        }
    }
}

// The mail composer sheet appears whenever reportEmail has a value.
extension ReportEmail: Identifiable {
    var id: String {
        "\(issueType.rawValue)-\(timestamp.timeIntervalSince1970)"
    }
}

#Preview {
    ContentView()
}
