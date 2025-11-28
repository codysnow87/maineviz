#!/usr/bin/env bash
set -o pipefail

echo "📡 Fetching Maine public schools locations..." >&2

PUBLIC_URL="https://nces.ed.gov/opengis/rest/services/K12_School_Locations/EDGE_GEOCODE_PUBLICSCH_2324/MapServer/0/query"
PUBLIC_JSON=$(curl -s "${PUBLIC_URL}?where=STFIP='23'&outFields=*&f=json&returnGeometry=false")

PUBLIC_COUNT=$(echo "$PUBLIC_JSON" | jq '.features | length')
echo "📦 Found $PUBLIC_COUNT public schools." >&2

echo "📡 Fetching Maine private schools..." >&2

PRIVATE_URL="https://nces.ed.gov/opengis/rest/services/K12_School_Locations/EDGE_GEOCODE_PRIVATESCH_2324/MapServer/0/query"
PRIVATE_JSON=$(curl -s "${PRIVATE_URL}?where=STFIP='23'&outFields=*&f=json&returnGeometry=false")

PRIVATE_COUNT=$(echo "$PRIVATE_JSON" | jq '.features | length')
echo "📦 Found $PRIVATE_COUNT private schools." >&2

echo "📡 Fetching detailed CCD data..." >&2

ADMIN_URL="https://nces.ed.gov/opengis/rest/services/K12_School_Locations/EDGE_ADMINDATA_PUBLICSCH_2223/MapServer/0/query"
ADMIN_JSON=$(curl -s "${ADMIN_URL}?where=STABR='ME'&outFields=*&f=json&returnGeometry=false")

ADMIN_COUNT=$(echo "$ADMIN_JSON" | jq '.features | length')
echo "📦 Fetched detailed data for $ADMIN_COUNT public schools." >&2

echo "📡 Fetching census demographics..." >&2

ACS_URL="https://api.census.gov/data/2023/acs/acs5/profile?get=NAME,DP03_0062E,DP03_0119PE,DP03_0128PE,DP05_0037E,DP05_0038E,DP05_0071E,DP02_0068PE,DP05_0018E,DP05_0001E&for=tract:*&in=state:23"
ACS_JSON=$(curl -s "$ACS_URL")

TRACT_COUNT=$(echo "$ACS_JSON" | jq 'length - 1')
echo "📦 Fetched demographics for $TRACT_COUNT census tracts." >&2

# Write data to temp files
SCHOOLS_FILE=$(mktemp)
ADMIN_FILE=$(mktemp)
ACS_FILE=$(mktemp)
GEOCODE_FILE=$(mktemp)
BATCH_INPUT=$(mktemp)
BATCH_CSV="${BATCH_INPUT}.csv"
BATCH_OUTPUT=$(mktemp)

# Combine schools
jq -n \
  --argjson public "$PUBLIC_JSON" \
  --argjson private "$PRIVATE_JSON" \
  '{features: (
    ($public.features | map(.attributes += {SCHOOL_TYPE: "Public"})) +
    ($private.features | map(.attributes += {SCHOOL_TYPE: "Private"}))
  )}' > "$SCHOOLS_FILE"

echo "$ADMIN_JSON" > "$ADMIN_FILE"
echo "$ACS_JSON" > "$ACS_FILE"

# Create geocoder input
jq -r '.features[].attributes | [.NAME, .STREET, .CITY, .STATE, .ZIP] | @tsv' "$SCHOOLS_FILE" | \
  awk 'BEGIN{FS="\t"; i=1} {if($2 && $3 && $4) print i++ "," $2 "," $3 "," $4 "," $5}' > "$BATCH_INPUT"

ROW_COUNT=$(wc -l < "$BATCH_INPUT" | tr -d ' ')
echo "📝 Geocoding $ROW_COUNT schools..." >&2

cp "$BATCH_INPUT" "$BATCH_CSV"

curl -s \
  --form "addressFile=@${BATCH_CSV};type=text/csv" \
  --form benchmark=Public_AR_Current \
  --form vintage=Current_Current \
  "https://geocoding.geo.census.gov/geocoder/geographies/addressbatch" \
  --output "$BATCH_OUTPUT"

echo "✅ Geocoding complete. Merging all data..." >&2

# Convert geocoder output to JSON
awk -F',' 'BEGIN{print "["} 
  {
    gsub(/"/, "", $1); gsub(/"/, "", $4); 
    gsub(/"/, "", $(NF-3)); gsub(/"/, "", $(NF-2)); 
    gsub(/"/, "", $(NF-1)); gsub(/"/, "", $NF);
    printf "%s{\"id\":%s,\"match\":\"%s\",\"state\":\"%s\",\"county\":\"%s\",\"tract\":\"%s\",\"block\":\"%s\"}", 
           (NR>1?",":""), $1, $4, $(NF-3), $(NF-2), $(NF-1), $NF
  } 
  END{print "]"}' "$BATCH_OUTPUT" > "$GEOCODE_FILE"

# Merge everything in jq using file inputs
jq -r --slurpfile schools "$SCHOOLS_FILE" \
      --slurpfile admin "$ADMIN_FILE" \
      --slurpfile acs "$ACS_FILE" \
      --slurpfile geocode "$GEOCODE_FILE" -n '
# Build lookup maps
($admin[0].features | map({key: .attributes.NCESSCH, value: .attributes}) | from_entries) as $adminMap |
($acs[0][1:] | map({key: (.[10] + .[11] + .[12]), value: .}) | from_entries) as $acsMap |
($geocode[0] | map({key: (.id | tostring), value: .}) | from_entries) as $geoMap |

# Output CSV header
"address,lat,lon,school_type,ncessch,status,level,grade_low,grade_high,enrollment,locale,county_name,fte,student_teacher_ratio,free_lunch,reduced_lunch,direct_cert,total_frl,virtual,charter,school_type_text,pk,kg,g01,g02,g03,g04,g05,g06,g07,g08,g09,g10,g11,g12,am,asian,black,hispanic,pacific,two_or_more,white,state,county,tract,block,geoid,income,poverty_total,poverty_below,poverty_rate,unemployment,white_census,black_census,hispanic_census,bachelors,median_age",

# Process each school
($schools[0].features | to_entries[] | 
  . as $entry |
  .value.attributes as $sch |
  (($entry.key + 1) | tostring) as $idx |
  $geoMap[$idx] as $geo |
  
  # Get admin data if public school
  (if $sch.SCHOOL_TYPE == "Public" then $adminMap[$sch.NCESSCH] else null end) as $adm |
  
  # Get ACS data
  (if $geo and $geo.state and $geo.county and $geo.tract 
   then $acsMap[$geo.state + $geo.county + $geo.tract] 
   else null end) as $dem |
  
  # Build address
  (($sch.NAME // "") + " - " + ($sch.STREET // "") + ", " + ($sch.CITY // "") + ", " + ($sch.STATE // "") + " " + ($sch.ZIP // "")) as $addr |
  
  # Calculate poverty
  (if $dem and $dem[2] and $dem[9] and ($dem[9] | tonumber) > 0 
   then (($dem[2] | tonumber) * ($dem[9] | tonumber) / 100 | floor)
   else "" end) as $pov_below |
  
  # Output CSV row
  [
    $addr,
    $sch.LAT // "",
    $sch.LON // "",    
    $sch.SCHOOL_TYPE // "",
    $sch.NCESSCH // ($sch.PPIN // ""),
    $adm.STATUS // "",
    $adm.SCHOOL_LEVEL // "",
    $adm.GSLO // "",
    $adm.GSHI // "",
    $adm.TOTAL // "",
    $sch.LOCALE // "",
    $sch.NMCNTY // "",
    $adm.FTE // "",
    $adm.STUTERATIO // "",
    $adm.FRELCH // "",
    $adm.REDLCH // "",
    $adm.DIRECTCERT // "",
    $adm.TOTFRL // "",
    $adm.VIRTUAL // "",
    $adm.CHARTER_TEXT // "",
    $adm.SCHOOL_TYPE_TEXT // "",
    $adm.PK // "",
    $adm.KG // "",
    $adm.G01 // "",
    $adm.G02 // "",
    $adm.G03 // "",
    $adm.G04 // "",
    $adm.G05 // "",
    $adm.G06 // "",
    $adm.G07 // "",
    $adm.G08 // "",
    $adm.G09 // "",
    $adm.G10 // "",
    $adm.G11 // "",
    $adm.G12 // "",
    $adm.AM // "",
    $adm.AS // "",
    $adm.BL // "",
    $adm.HI // "",
    $adm.HP // "",
    $adm.TR // "",
    $adm.WH // "",
    $geo.state // "",
    $geo.county // "",
    $geo.tract // "",
    $geo.block // "",
    (if $geo.state and $geo.county and $geo.tract then ($geo.state + $geo.county + $geo.tract) else "" end),
    $dem[1] // "",
    $dem[9] // "",
    $pov_below,
    $dem[2] // "",
    $dem[3] // "",
    $dem[4] // "",
    $dem[5] // "",
    $dem[6] // "",
    $dem[7] // "",
    $dem[8] // ""
  ] | @csv
)
'

echo "🎉 Done!" >&2
rm -f "$SCHOOLS_FILE" "$ADMIN_FILE" "$ACS_FILE" "$GEOCODE_FILE" "$BATCH_INPUT" "$BATCH_CSV" "$BATCH_OUTPUT"