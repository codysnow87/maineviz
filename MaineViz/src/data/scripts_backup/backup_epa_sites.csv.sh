#!/usr/bin/env bash
# Fetch EPA contaminated sites for Maine

set -o pipefail

echo "📡 Fetching EPA contaminated sites for Maine..." >&2

# Fetch Toxic Release Inventory facilities
echo "   Fetching TRI facilities..." >&2
TRI_URL="https://data.epa.gov/efservice/tri_facility/state_abbr/ME/rows/0:2000/JSON"
TRI=$(curl -s "$TRI_URL" 2>/dev/null)

if ! echo "$TRI" | jq empty 2>/dev/null; then
  echo "      ⚠️  Failed to fetch TRI data" >&2
  exit 1
fi

TRI_COUNT=$(echo "$TRI" | jq 'length')
echo "      Found $TRI_COUNT TRI facilities" >&2

echo "   Processing site data..." >&2

# Output TRI facilities - FIX: negate longitude for western hemisphere
echo "$TRI" | jq -r '
# CSV header
"site_id,site_name,lat,lon,type,status,npl_status,city,zip,county,address",

# Process each facility
(.[] | 
  select(.pref_latitude and .pref_longitude) | 
  [
    .tri_facility_id,
    .facility_name,
    .pref_latitude,
    (-.pref_longitude),
    "TRI Facility",
    (if .fac_closed_ind == "1" then "Closed" else "Active" end),
    "",
    .city_name,
    .zip_code,
    .county_name,
    (.street_address + ", " + .city_name + ", ME " + .zip_code)
  ] | @csv
)
'

echo "✅ EPA sites data complete" >&2