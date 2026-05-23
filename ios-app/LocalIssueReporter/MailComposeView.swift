import MessageUI
import SwiftUI
import UIKit

// MessageUI is a UIKit framework. UIViewControllerRepresentable lets SwiftUI
// present MFMailComposeViewController as a normal SwiftUI sheet.
struct MailComposeView: UIViewControllerRepresentable {
    let report: ReportEmail
    let onFinish: (MFMailComposeResult) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        // The coordinator listens for the mail composer finishing or being cancelled.
        Coordinator(mailComposeView: self)
    }

    // Creates the native iOS mail compose sheet. This uses MessageUI, so the user
    // stays in the app while reviewing and sending the generated email.
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposeController = MFMailComposeViewController()
        mailComposeController.mailComposeDelegate = context.coordinator
        mailComposeController.setToRecipients([report.destinationEmailAddress])
        mailComposeController.setSubject(report.subject)
        mailComposeController.setMessageBody(report.body, isHTML: false)

        if let csvData = report.csvAttachment.data(using: .utf8) {
            mailComposeController.addAttachmentData(
                csvData,
                mimeType: "text/csv",
                fileName: "local-issue-report-\(report.reportID).csv"
            )
        }

        for (index, photo) in report.photos.enumerated() {
            guard let photoData = photo.jpegData(compressionQuality: 0.85) else {
                continue
            }

            let fileName = report.photos.count == 1
                ? "local-issue-report.jpg"
                : "local-issue-report-\(index + 1).jpg"

            mailComposeController.addAttachmentData(
                photoData,
                mimeType: "image/jpeg",
                fileName: fileName
            )
        }

        return mailComposeController
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let mailComposeView: MailComposeView

        init(mailComposeView: MailComposeView) {
            self.mailComposeView = mailComposeView
        }

        // Called after the user sends, saves, cancels, or fails to send the email.
        // The callback lets ContentView decide what should happen next.
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            mailComposeView.dismiss()
            mailComposeView.onFinish(result)
        }
    }
}

struct ReportEmail {
    let reportID: String
    let destinationEmailAddress: String
    let issueType: IssueType
    let notes: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let photos: [UIImage]

    // The subject matches the required report format.
    var subject: String {
        "Local Issue Report - \(issueType.rawValue)"
    }

    // This plain-text body is what the user sees in the Mail compose sheet.
    var body: String {
        """
        Report ID: \(reportID)
        Issue type: \(issueType.rawValue)
        Notes: \(notes.isEmpty ? "None provided" : notes)
        Latitude: \(latitude)
        Longitude: \(longitude)
        Apple Maps link: \(appleMapsLink)
        Timestamp: \(Self.timestampFormatter.string(from: timestamp))
        """
    }

    var csvAttachment: String {
        let headers = [
            "report_id",
            "issue_type",
            "notes",
            "latitude",
            "longitude",
            "apple_maps_link",
            "timestamp",
            "destination_email",
            "photo_count"
        ]

        let row = [
            reportID,
            issueType.rawValue,
            notes,
            String(latitude),
            String(longitude),
            appleMapsLink,
            Self.timestampFormatter.string(from: timestamp),
            destinationEmailAddress,
            String(photos.count)
        ]

        return [
            headers.joined(separator: ","),
            row.map(Self.csvEscaped).joined(separator: ",")
        ].joined(separator: "\n")
    }

    var appleMapsLink: String {
        "https://maps.apple.com/?q=Reported%20Issue%20\(reportID)&ll=\(latitude),\(longitude)"
    }

    private static func csvEscaped(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
