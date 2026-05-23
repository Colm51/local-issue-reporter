import html
import os
from datetime import date
from pathlib import Path

try:
    from branca.element import Element
    import folium
    import geopandas as gpd
    import pandas as pd
except ImportError as error:
    missing_package = error.name
    print(f"Missing required Python package: {missing_package}")
    print("Install the required packages with:")
    print("python3 -m pip install pandas folium geopandas branca")
    raise SystemExit(1)


WORKFLOW_FOLDER = Path(__file__).resolve().parent
REPORTS_FOLDER = Path(os.environ.get("LOCAL_ISSUE_REPORTS_FOLDER", WORKFLOW_FOLDER / "sample_data"))
BIKE_LANES_PATH = Path(os.environ.get("LOCAL_ISSUE_BIKE_LANES_PATH", WORKFLOW_FOLDER / "data" / "cycling-network-4326.gpkg"))
TODAY_STRING = date.today().isoformat()

EXPECTED_COLUMNS = [
    "report_id",
    "issue_type",
    "notes",
    "latitude",
    "longitude",
    "apple_maps_link",
    "timestamp",
    "destination_email",
    "photo_count",
]

MARKER_COLORS = [
    "red",
    "blue",
    "green",
    "purple",
    "orange",
    "darkred",
    "lightred",
    "beige",
    "darkblue",
    "darkgreen",
    "cadetblue",
    "darkpurple",
    "pink",
    "lightblue",
    "lightgreen",
    "gray",
    "black",
    "lightgray",
]


def read_csv_files():
    """Read every CSV export in the Reports folder into one DataFrame."""
    csv_files = sorted(REPORTS_FOLDER.glob("*.csv"))
    csv_files = [
        file_path
        for file_path in csv_files
        if not file_path.name.startswith("combined_reports_cleaned")
    ]

    if not csv_files:
        print(f"No CSV files found in {REPORTS_FOLDER}")
        return pd.DataFrame(columns=EXPECTED_COLUMNS)

    print(f"Found {len(csv_files)} CSV file(s):")
    frames = []

    for csv_file in csv_files:
        print(f"- Reading {csv_file.name}")
        frame = pd.read_csv(csv_file, dtype={"report_id": "string"})
        frames.append(frame)

    combined = pd.concat(frames, ignore_index=True)
    print(f"Combined {len(combined)} row(s) before cleaning.")
    return combined


def get_output_paths():
    """Choose today's next available map and cleaned CSV filenames."""
    version = 1

    while True:
        map_path = REPORTS_FOLDER / f"local_issue_report_map_{TODAY_STRING}_v{version}.html"
        csv_path = REPORTS_FOLDER / f"combined_reports_cleaned_{TODAY_STRING}_v{version}.csv"

        if not map_path.exists() and not csv_path.exists():
            return map_path, csv_path

        version += 1


def read_bike_lanes():
    """Read the bike lanes GeoPackage for the optional map layer."""
    if not BIKE_LANES_PATH.exists():
        print(f"Warning: Bike lanes file not found at {BIKE_LANES_PATH}")
        return None

    try:
        print(f"Reading bike lanes from {BIKE_LANES_PATH}")
        bike_lanes = gpd.read_file(BIKE_LANES_PATH)

        if bike_lanes.crs is None:
            print("Warning: Bike lanes CRS is missing. Assuming EPSG:4326.")
            bike_lanes = bike_lanes.set_crs(epsg=4326)
        elif bike_lanes.crs.to_epsg() != 4326:
            print("Converting bike lanes to EPSG:4326.")
            bike_lanes = bike_lanes.to_crs(epsg=4326)

        return bike_lanes
    except Exception as error:
        print(f"Warning: Could not read bike lanes: {error}")
        return None


def clean_reports(reports):
    """Keep useful columns, preserve report IDs, and remove invalid coordinates."""
    print("Cleaning report data...")

    for column in EXPECTED_COLUMNS:
        if column not in reports.columns:
            reports[column] = ""

    reports = reports[EXPECTED_COLUMNS].copy()
    reports["report_id"] = reports["report_id"].astype("string")
    reports["latitude"] = pd.to_numeric(reports["latitude"], errors="coerce")
    reports["longitude"] = pd.to_numeric(reports["longitude"], errors="coerce")

    before_count = len(reports)
    reports = reports.dropna(subset=["latitude", "longitude"])
    after_count = len(reports)

    print(f"Dropped {before_count - after_count} row(s) missing valid coordinates.")
    print(f"Kept {after_count} clean report row(s).")
    return reports


def make_popup_text(report):
    """Create simple popup text for one map marker."""
    report_id = report.get("report_id", "")
    issue_type = report.get("issue_type", "")
    timestamp = report.get("timestamp", "")
    notes = report.get("notes", "")
    photo_count = report.get("photo_count", "")

    return (
        f"<b>Report ID:</b> {report_id}<br>"
        f"<b>Issue type:</b> {issue_type}<br>"
        f"<b>Timestamp:</b> {timestamp}<br>"
        f"<b>Notes:</b> {notes}<br>"
        f"<b>Photo count:</b> {photo_count}"
    )


def get_issue_type_colors(reports):
    """Assign one marker color to each issue type."""
    issue_types = sorted(reports["issue_type"].dropna().astype(str).unique())

    return {
        issue_type: MARKER_COLORS[index % len(MARKER_COLORS)]
        for index, issue_type in enumerate(issue_types)
    }


def add_legend(report_map, issue_type_colors):
    """Add a simple issue type color legend to the map."""
    rows = []

    for issue_type, color in issue_type_colors.items():
        escaped_issue_type = html.escape(issue_type)
        rows.append(
            f"""
            <div style="margin-top: 4px;">
                <span style="
                    background: {color};
                    border: 1px solid #333;
                    display: inline-block;
                    height: 11px;
                    margin-right: 6px;
                    width: 11px;
                "></span>
                {escaped_issue_type}
            </div>
            """
        )

    legend_html = f"""
    <div style="
        background: white;
        border: 2px solid #333;
        bottom: 24px;
        box-sizing: border-box;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
        font-size: 13px;
        left: 24px;
        padding: 10px;
        position: fixed;
        width: 260px;
        z-index: 9999;
    ">
        <div style="font-weight: 700; margin-bottom: 6px;">
            Reports from Local Issue Reporter
        </div>
        {''.join(rows)}
    </div>
    """

    report_map.get_root().html.add_child(Element(legend_html))


def add_bike_lanes_layer(report_map, bike_lanes):
    """Add bike lanes to the map as a toggleable line layer."""
    if bike_lanes is None or bike_lanes.empty:
        return

    folium.GeoJson(
        bike_lanes,
        name="Bike lanes",
        style_function=lambda feature: {
            "color": "#0077cc",
            "weight": 1.5,
            "opacity": 0.8,
        },
    ).add_to(report_map)


def add_bike_lanes_legend(report_map):
    """Add a small legend explaining the bike lanes layer."""
    legend_html = """
    <div style="
        background: white;
        border: 2px solid #333;
        bottom: 138px;
        box-sizing: border-box;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
        font-size: 13px;
        left: 24px;
        padding: 10px;
        position: fixed;
        width: 260px;
        z-index: 9999;
    ">
        <span style="
            border-top: 2px solid #0077cc;
            display: inline-block;
            margin-right: 6px;
            vertical-align: middle;
            width: 28px;
        "></span>
        Bike lanes and multi-use trails
    </div>
    """

    report_map.get_root().html.add_child(Element(legend_html))


def create_map(reports, map_output_path, bike_lanes):
    """Create and save an interactive Folium map."""
    if reports.empty:
        print("No reports with valid coordinates. Creating an empty map.")
        report_map = folium.Map(location=[0, 0], zoom_start=2)
    else:
        center_latitude = reports["latitude"].mean()
        center_longitude = reports["longitude"].mean()
        report_map = folium.Map(
            location=[center_latitude, center_longitude],
            zoom_start=13,
        )

        print("Adding report markers to the map...")
        issue_type_colors = get_issue_type_colors(reports)

        for _, report in reports.iterrows():
            issue_type = str(report.get("issue_type", ""))
            marker_color = issue_type_colors.get(issue_type, "blue")

            folium.Marker(
                location=[report["latitude"], report["longitude"]],
                icon=folium.Icon(color=marker_color),
                popup=folium.Popup(make_popup_text(report), max_width=300),
                tooltip=f"{report['report_id']} - {issue_type}",
            ).add_to(report_map)

        add_legend(report_map, issue_type_colors)

    add_bike_lanes_layer(report_map, bike_lanes)
    add_bike_lanes_legend(report_map)
    folium.LayerControl().add_to(report_map)

    report_map.save(map_output_path)
    print(f"Saved map to {map_output_path}")


def main():
    print("LocalIssueReporter CSV map builder")
    print(f"Reading CSV exports from {REPORTS_FOLDER}")

    reports = read_csv_files()
    bike_lanes = read_bike_lanes()
    cleaned_reports = clean_reports(reports)
    map_output_path, cleaned_csv_output_path = get_output_paths()

    cleaned_reports.to_csv(cleaned_csv_output_path, index=False)
    print(f"Saved cleaned CSV to {cleaned_csv_output_path}")

    create_map(cleaned_reports, map_output_path, bike_lanes)
    print("Done.")


if __name__ == "__main__":
    main()
