import Foundation
import SwiftUI
import UIKit

struct SubmittedReport: Identifiable, Codable {
    let id: UUID
    let reportID: String
    let issueType: String
    let notes: String
    let latitude: Double
    let longitude: Double
    let appleMapsLink: String
    let timestamp: Date
    let destinationEmailAddress: String
    let photoCount: Int

    init(report: ReportEmail) {
        id = UUID()
        reportID = report.reportID
        issueType = report.issueType.rawValue
        notes = report.notes
        latitude = report.latitude
        longitude = report.longitude
        appleMapsLink = report.appleMapsLink
        timestamp = report.timestamp
        destinationEmailAddress = report.destinationEmailAddress
        photoCount = report.photos.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        reportID = try container.decodeIfPresent(String.self, forKey: .reportID) ?? String(id.uuidString.prefix(6)).uppercased()
        issueType = try container.decode(String.self, forKey: .issueType)
        notes = try container.decode(String.self, forKey: .notes)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        appleMapsLink = try container.decode(String.self, forKey: .appleMapsLink)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        destinationEmailAddress = try container.decode(String.self, forKey: .destinationEmailAddress)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
    }
}

final class SubmittedReportStore: ObservableObject {
    @Published private(set) var reports: [SubmittedReport] = []

    private let userDefaultsKey = "submittedReports"

    init() {
        loadReports()
    }

    func add(_ report: SubmittedReport) {
        reports.insert(report, at: 0)
        saveReports()
        print("LocalIssueReporter debug: Saved submitted report. Stored report count: \(reports.count)")
    }

    func deleteAllReports() {
        reports = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("LocalIssueReporter debug: Deleted all submitted reports.")
    }

    func makeExportFile() -> URL? {
        let csv = makeCSV()
        let dateString = Self.exportFileDateFormatter.string(from: Date())
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("submitted-reports-\(dateString).csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("LocalIssueReporter debug: Could not write submitted reports CSV: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            reports = []
            print("LocalIssueReporter debug: No submitted reports found in UserDefaults.")
            return
        }

        reports = (try? JSONDecoder().decode([SubmittedReport].self, from: data)) ?? []
        print("LocalIssueReporter debug: Loaded submitted reports from UserDefaults. Count: \(reports.count)")
    }

    private func saveReports() {
        guard let data = try? JSONEncoder().encode(reports) else {
            return
        }

        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func makeCSV() -> String {
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

        let rows = reports.map { report in
            [
                report.reportID,
                report.issueType,
                report.notes,
                String(report.latitude),
                String(report.longitude),
                report.appleMapsLink,
                Self.timestampFormatter.string(from: report.timestamp),
                report.destinationEmailAddress,
                String(report.photoCount)
            ]
            .map(Self.csvEscaped)
            .joined(separator: ",")
        }

        return ([headers.joined(separator: ",")] + rows).joined(separator: "\n")
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

    private static let exportFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct SubmittedReportsView: View {
    @ObservedObject var store: SubmittedReportStore
    @State private var isShowingDeleteConfirmation = false
    @State private var exportFile: CSVExportFile?
    @State private var exportMessage: String?

    var body: some View {
        List {
            if store.reports.isEmpty {
                Text("No submitted reports yet")
                    .foregroundStyle(.secondary)
            } else {
                Button("Export All as CSV") {
                    guard !store.reports.isEmpty else {
                        exportMessage = "There are no submitted reports to export yet."
                        return
                    }

                    guard let fileURL = store.makeExportFile(),
                          FileManager.default.fileExists(atPath: fileURL.path) else {
                        exportMessage = "The submitted reports CSV could not be created."
                        return
                    }

                    exportFile = CSVExportFile(url: fileURL)
                }

                ForEach(store.reports) { report in
                    NavigationLink {
                        SubmittedReportDetailView(report: report)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(report.issueType) - \(report.reportID)")
                                .font(.headline)

                            Text(Self.timestampFormatter.string(from: report.timestamp))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Lat: \(report.latitude), Long: \(report.longitude)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Submitted Reports")
        .toolbar {
            if !store.reports.isEmpty {
                Button("Clear") {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Delete all submitted reports?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Reports", role: .destructive) {
                store.deleteAllReports()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the local submitted reports history from this iPhone.")
        }
        .sheet(item: $exportFile) { exportFile in
            ShareSheet(items: [exportFile.url])
        }
        .alert(
            "Export CSV",
            isPresented: Binding(
                get: { exportMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        exportMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text(exportMessage ?? "")
        }
        .onAppear {
            print("LocalIssueReporter debug: SubmittedReportsView appeared with \(store.reports.count) reports.")
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct CSVExportFile: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

struct SubmittedReportDetailView: View {
    let report: SubmittedReport

    var body: some View {
        Form {
            Section("Issue") {
                LabeledContent("Report ID", value: report.reportID)
                LabeledContent("Issue type", value: report.issueType)
                LabeledContent("Notes", value: report.notes.isEmpty ? "None provided" : report.notes)
            }

            Section("Location") {
                LabeledContent("Latitude", value: String(report.latitude))
                LabeledContent("Longitude", value: String(report.longitude))
                LabeledContent("Apple Maps link", value: report.appleMapsLink)
            }

            Section("Email") {
                LabeledContent("Destination", value: report.destinationEmailAddress)
                LabeledContent("Photo count", value: String(report.photoCount))
            }

            Section("Submitted") {
                LabeledContent("Timestamp", value: Self.timestampFormatter.string(from: report.timestamp))
            }
        }
        .navigationTitle("Report Details")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
