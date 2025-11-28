#!/usr/bin/env bash
# Fetch historical enrollment for Maine public schools

set -o pipefail

echo "📊 Fetching historical enrollment data for Maine public schools..." >&2

# Years available in ADMINDATA (school year ending)
YEARS=(2023 2022 2021 2020 2019 2018)

# Output header
echo "ncessch,school_name,year,enrollment,fte,student_teacher_ratio"

for YEAR in "${YEARS[@]}"; do
  # Map year to dataset name
  if [ "$YEAR" = "2023" ]; then
    DATASET="2223"
  elif [ "$YEAR" = "2022" ]; then
    DATASET="2122"
  elif [ "$YEAR" = "2021" ]; then
    DATASET="2021"
  elif [ "$YEAR" = "2020" ]; then
    DATASET="1920"
  elif [ "$YEAR" = "2019" ]; then
    DATASET="1819"
  elif [ "$YEAR" = "2018" ]; then
    DATASET="1718"
  fi
  
  echo "   Fetching school year ${YEAR}..." >&2
  
  ADMIN_URL="https://nces.ed.gov/opengis/rest/services/K12_School_Locations/EDGE_ADMINDATA_PUBLICSCH_${DATASET}/MapServer/0/query"
  ADMIN_PARAMS="where=STABR='ME'&outFields=NCESSCH,SCH_NAME,TOTAL,FTE,STUTERATIO&f=json&returnGeometry=false"
  
  RESULT=$(curl -s "${ADMIN_URL}?${ADMIN_PARAMS}")
  
  if echo "$RESULT" | jq empty 2>/dev/null; then
    COUNT=$(echo "$RESULT" | jq '.features | length')
    echo "      Got $COUNT schools" >&2
    
    echo "$RESULT" | jq -r --arg yr "$YEAR" '.features[].attributes | 
      [.NCESSCH, .SCH_NAME, $yr, .TOTAL // "", .FTE // "", .STUTERATIO // ""] | 
      @csv'
  else
    echo "      ⚠️  Failed to fetch year $YEAR" >&2
  fi
  
  sleep 0.5
done

echo "✅ Enrollment time series complete" >&2