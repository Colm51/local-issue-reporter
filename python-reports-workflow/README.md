# Python Reports Mapping Workflow

This folder contains the optional Python workflow for mapping CSV exports from LocalIssueReporter.

It is separate from the SwiftUI iOS app. The iOS app can run without this folder.

## What The Script Does

`create_local_issue_report_map.py`:

- reads LocalIssueReporter CSV exports
- combines them into one pandas DataFrame
- preserves `report_id` as text
- converts latitude and longitude to numbers
- drops rows without valid coordinates
- saves a cleaned combined CSV
- creates an interactive Folium HTML map
- colors report markers by `issue_type`
- shows report details in marker tooltips and popups
- optionally overlays bike lanes and multi-use trails from a local GeoPackage

Generated maps and cleaned CSV files are intentionally ignored by Git.

## Setup

Create and activate a virtual environment:

```bash
python3 -m venv reports_env
source reports_env/bin/activate
```

Install dependencies:

```bash
python3 -m pip install pandas folium geopandas branca
```

## Input CSV Files

By default, the script reads CSV files from:

```text
sample_data/
```

For real report exports, either copy CSV files into a local working folder or set:

```bash
export LOCAL_ISSUE_REPORTS_FOLDER="/path/to/your/report/csvs"
```


## Bike Lane And Multi-Use Trail Data

The script can add a bike lane and multi-use trail layer from a local GeoPackage file.

By default, it looks for:

```text
data/cycling-network-4326.gpkg
```

That file is not included in this public repository. Municipalities or civic-tech users should provide their own local cycling network dataset.

You can also set a custom path:

```bash
export LOCAL_ISSUE_BIKE_LANES_PATH="/path/to/your/cycling-network.gpkg"
```

The GeoPackage should use EPSG:4326 if possible. If it uses another CRS, the script attempts to convert it to EPSG:4326.

## Run The Workflow

```bash
python3 create_local_issue_report_map.py
```

The script writes dated and versioned outputs to the reports folder, for example:

```text
combined_reports_cleaned_2026-05-23_v1.csv
local_issue_report_map_2026-05-23_v1.html
```

If version 1 already exists, the script creates version 2, then version 3, and so on.



