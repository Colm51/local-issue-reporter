import Foundation

struct DraftReport: Codable {
    let issueType: String
    let notes: String
    let destinationEmailAddress: String
    let latitude: Double
    let longitude: Double
    let photoFileNames: [String]
    let savedAt: Date
}
