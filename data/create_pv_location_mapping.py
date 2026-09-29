import pandas as pd


print("--------------------------------")
print("RaySense PV Location Mapping")
print("--------------------------------")


# Load Kerala location metadata
metadata_file = "data/metadata/kerala_distpv_points.csv"

locations = pd.read_csv(metadata_file)


# Create mapping between PV point and real location
mapping = locations[
    ["Unnamed: 0", "latitude", "longitude", "elevation", "gid"]
].copy()


mapping.insert(
    0,
    "pv_point",
    ["point_" + str(i) for i in range(len(mapping))]
)


# Save mapping
output_file = "data/metadata/pv_location_mapping.csv"

mapping.to_csv(
    output_file,
    index=False
)


print()
print("Total PV points:", len(mapping))
print("Mapping saved to:", output_file)

print()
print("First 10 mappings:")
print(mapping.head(10).to_string(index=False))

print()
print("--------------------------------")
print("STEP 34 COMPLETED")
print("--------------------------------")