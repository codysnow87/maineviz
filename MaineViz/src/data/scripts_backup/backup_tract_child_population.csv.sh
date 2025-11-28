#!/usr/bin/env bash
# Fetch tract-level child population (under 5) time series for Maine

set -o pipefail

echo "📊 Fetching Maine tract-level child population (under 5) for past 10 years..." >&2

START_YEAR=2014
END_YEAR=2023 # last available year

# Output header
echo "geoid,tract_name,year,pop_under_5,total_pop,pct_under_5"

for YEAR in $(seq $START_YEAR $END_YEAR); do
  echo "   Fetching year $YEAR..." >&2
  
  # B01001_003E: Male population under 5
  # B01001_027E: Female population under 5
  # B01001_001E: Total population
  
  URL="https://api.census.gov/data/${YEAR}/acs/acs5?get=NAME,B01001_003E,B01001_027E,B01001_001E&for=tract:*&in=state:23"
  
  RESULT=$(curl -s "$URL")
  
  if echo "$RESULT" | jq empty 2>/dev/null; then
    echo "$RESULT" | jq -r --arg yr "$YEAR" '
      .[1:] | .[] |
      (.[1] | tonumber) as $male_u5 |
      (.[2] | tonumber) as $female_u5 |
      (.[3] | tonumber) as $total |
      ($male_u5 + $female_u5) as $under5 |
      (if $total > 0 then (($under5 / $total) * 100) else 0 end) as $pct |
      [
        (.[4] + .[5] + .[6]),
        (.[0] | gsub(", Maine"; "")),
        $yr,
        $under5,
        $total,
        ($pct | tostring)
      ] | @csv
    '
  else
    echo "   ⚠️  Failed to fetch data for year $YEAR" >&2
  fi
  
  sleep 0.5
done

echo "✅ Child population data complete" >&2