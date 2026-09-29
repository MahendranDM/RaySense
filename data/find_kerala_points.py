import pandas as pd
import geopandas as gpd

# Read GridLab metadata
metadata = pd.read_csv(
    "data/metadata/distpv_metadata.csv"
)

# Convert latitude and longitude into map points
points = gpd.GeoDataFrame(
    metadata,
    geometry=gpd.points_from_xy(
        metadata["longitude"],
        metadata["latitude"]
    ),
    crs="EPSG:4326"
)

# Read Kerala boundary
kerala = gpd.read_file(
    "data/metadata/state.geojson"
)

# Make sure the boundary uses the same coordinate system
kerala = kerala.to_crs("EPSG:4326")

# Select Kerala
kerala = kerala[kerala["ST_NM"] == "Kerala"]

# Find GridLab points inside Kerala
kerala_points = gpd.sjoin(
    points,
    kerala,
    predicate="within",
    how="inner"
)

# Keep only the information we need
kerala_points = kerala_points[
    ["Unnamed: 0", "latitude", "longitude", "elevation", "gid"]
]

# Save the Kerala locations
output_file = "data/metadata/kerala_distpv_points.csv"

kerala_points.to_csv(
    output_file,
    index=False
)

print("--------------------------------")
print("RaySense Kerala Location Search")
print("--------------------------------")
print("Total India points :", len(metadata))
print("Kerala points      :", len(kerala_points))
print("--------------------------------")
print()
print(kerala_points.head(10))