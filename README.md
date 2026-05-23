# LocalIssueReporter Public Repository

This repository contains two related but separate parts:

- `ios-app/` - the SwiftUI iOS prototype app
- `python-reports-workflow/` - the optional local Python workflow for mapping exported report CSV files

The iOS app does not require the Python workflow to run. The Python workflow is for local analysis after report CSV files have been exported.

## iOS App

The app lets a user create a local issue report, attach photos, capture location coordinates, and send the report through the native iOS Mail composer.

The public version uses this placeholder destination email:

```text
reports@example.com
```

Anyone adapting the project should replace that value with their own reporting address.

Open the Xcode project from:

```text
ios-app/LocalIssueReporter.xcodeproj
```

Each developer must configure their own Apple signing team in Xcode before running on a physical device.

## Python Reports Workflow

The Python workflow reads LocalIssueReporter CSV exports, combines and cleans them, and creates an interactive Folium map.

See:

```text
python-reports-workflow/README.md
```

The workflow no longer uses hard-coded local machine paths. It supports:

- a default local `sample_data/` folder
- `LOCAL_ISSUE_REPORTS_FOLDER` for real CSV exports
- `LOCAL_ISSUE_BIKE_LANES_PATH` for a local cycling network GeoPackage

Real report CSV exports, generated HTML maps, generated cleaned CSVs, Python virtual environments, and local GIS datasets should not be committed.

## Public Repository Safety

This repository is prepared to avoid committing:

- personal destination emails
- local Mac paths
- nested Git repositories
- Xcode user state
- Python virtual environments
- `.DS_Store` files
- generated CSV exports
- generated HTML maps
- local GeoPackage datasets

Before publishing, run a final review for private data, real report exports, personal identifiers, and local-only files.

