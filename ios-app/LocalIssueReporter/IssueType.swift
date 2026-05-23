import Foundation

// This enum is the list of choices shown in the Issue Type picker.
// CaseIterable lets the picker loop through all cases automatically.
enum IssueType: String, CaseIterable, Identifiable {
    case pothole = "Pothole"
    case bikeLane = "Bike Lane Issue"
    case brokenSidewalk = "Broken Sidewalk"
    case streetlight = "Streetlight Issue"
    case trash = "Trash or Debris"
    case other = "Other"

    // SwiftUI lists and pickers need a stable id for each row.
    var id: String {
        rawValue
    }
}
