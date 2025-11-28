```js
import * as Plot from "npm:@observablehq/plot";
import {feature} from "npm:topojson-client";

// Load all our datasets 
const demographics = await FileAttachment("data/demographics.csv").csv({typed: true});
const epaSites = await FileAttachment("data/epa_sites.csv").csv({typed: true});
const childPop = await FileAttachment("data/tract_child_population.csv").csv({typed: true});
const enrollmentHistory = await FileAttachment("data/school_enrollment_timeseries.csv").csv({typed: true});

// Load county boundaries
const us = await fetch("https://cdn.jsdelivr.net/npm/us-atlas@3/counties-10m.json").then(r => r.json());
const counties = feature(us, us.objects.counties)
  .features
  .filter(d => d.id.startsWith("23"));

// Helper functions
function distance(lat1, lon1, lat2, lon2) {
  const R = 3959;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function formatStatus(status) {
  const statuses = {"1": "Currently operational", "2": "Closed", "3": "Future", "4": "Inactive"};
  return statuses[status] || status || "N/A";
}

// Map locale codes to descriptive text (NCES Urban-Centric Locale Framework)
function formatLocale(code) {
  const locales = {
    "11": "City: Large",
    "12": "City: Midsize",
    "13": "City: Small",
    "21": "Suburb: Large",
    "22": "Suburb: Midsize",
    "23": "Suburb: Small",
    "31": "Town: Fringe",
    "32": "Town: Distant",
    "33": "Town: Remote",
    "41": "Rural: Fringe",
    "42": "Rural: Distant",
    "43": "Rural: Remote"
  };
  return locales[code] || code || "N/A";
}

// Determine school level from grade range
function determineSchoolLevel(gradeLow, gradeHigh) {
  // Convert grade codes to numbers
  const gradeMap = {
    "PK": -1, "KG": 0, "K": 0,
    "1": 1, "2": 2, "3": 3, "4": 4, "5": 5,
    "6": 6, "7": 7, "8": 8, 
    "9": 9, "10": 10, "11": 11, "12": 12
  };
  
  const low = gradeMap[gradeLow] ?? 0;
  const high = gradeMap[gradeHigh] ?? 12;
  
  // Elementary: PreK-5 or K-6
  if (high <= 6 && low <= 0) return "Elementary";
  
  // Middle: typically 6-8 or 7-8
  if (low >= 5 && high <= 8) return "Middle";
  
  // High: typically 9-12
  if (low >= 9 && high <= 12) return "High";
  
  // Multi-level schools
  if (low <= 0 && high >= 9) return "Multi-Level";
  
  return "Other";
}

// Prepare schools with EPA proximity and formatted locale
const schools = demographics
  .filter(d => d.lat && d.lon && d.address)
  .map(school => ({
    ...school,
    nearEPA: epaSites.some(site => distance(school.lat, school.lon, site.lat, site.lon) < 2),
    schoolLevel: determineSchoolLevel(school.grade_low, school.grade_high),
    localeText: formatLocale(school.locale)
  }));
```

```js
// ============================================================================
// RISK SCORE CALCULATION
// ============================================================================
// Calculate closure risk scores for each school based on weighted factors:
// - Enrollment decline (>10% decline triggers factor)
// - Child population decline in census tract (>5% decline triggers factor)
// - Poverty rate (normalized from 15-35%)
// - Low education attainment (normalized from 5-20% bachelor's degree)
// - Unemployment rate (normalized from 5-15%)
// Final score is normalized to 0-10 scale

console.log("Total schools before risk calculation:", schools.length);

const schoolsWithRisk = schools.map(school => {
  let riskScore = 0;
  let riskFactors = [];
  
  // 1. Enrollment decline (if data available)
  const enrollmentData = school.ncessch ? 
    enrollmentHistory.filter(d => d.ncessch === school.ncessch).sort((a, b) => a.year - b.year) : [];
  
  if (enrollmentData.length > 1) {
    const enrollTrend = ((enrollmentData[enrollmentData.length - 1].enrollment - enrollmentData[0].enrollment) / enrollmentData[0].enrollment * 100);
    if (enrollTrend < -10) {
      riskScore += enrollmentDeclineWeight;
      riskFactors.push(`Enrollment declining (${enrollTrend.toFixed(1)}%)`);
    }
  }
  
  // 2. Child population decline (if data available)
  const tractData = school.geoid ? 
    childPop.filter(d => d.geoid === school.geoid).sort((a, b) => a.year - b.year) : [];
  
  if (tractData.length > 0) {
    const childPopTrend = ((tractData[tractData.length - 1].pop_under_5 - tractData[0].pop_under_5) / tractData[0].pop_under_5 * 100);
    if (childPopTrend < -5) {
      riskScore += childPopDeclineWeight;
      riskFactors.push(`Child population declining (${childPopTrend.toFixed(1)}%)`);
    }
  }
  
  // 3. Poverty rate (higher is riskier)
  if (school.poverty_rate && school.poverty_rate > 15) {
    const povertyFactor = Math.min((school.poverty_rate - 15) / 20, 1); // Normalize 15-35% to 0-1
    riskScore += povertyWeight * povertyFactor;
    riskFactors.push(`High poverty (${school.poverty_rate.toFixed(1)}%)`);
  }
  
  // 4. Education level (lower bachelor's degree attainment is riskier)
  if (school.bachelors && school.bachelors < 20) {
    const educationFactor = Math.min((20 - school.bachelors) / 15, 1); // Normalize 5-20% to 0-1
    riskScore += educationWeight * educationFactor;
    riskFactors.push(`Low education (${school.bachelors.toFixed(1)}% bachelor's)`);
  }
  
  // 5. Unemployment rate (higher is riskier)
  if (school.unemployment && school.unemployment > 5) {
    const unemploymentFactor = Math.min((school.unemployment - 5) / 10, 1); // Normalize 5-15% to 0-1
    riskScore += unemploymentWeight * unemploymentFactor;
    riskFactors.push(`High unemployment (${school.unemployment.toFixed(1)}%)`);
  }
  
  // Normalize to 0-10 scale
  const maxPossibleScore = enrollmentDeclineWeight + childPopDeclineWeight + 
                           povertyWeight + educationWeight + unemploymentWeight;
  const normalizedRisk = maxPossibleScore > 0 ? (riskScore / maxPossibleScore) * 10 : 0;
  
  return {
    ...school,
    riskScore: Math.min(normalizedRisk, 10) || 0, // Ensure we don't get NaN
    riskFactors
  };
});

console.log("Schools with risk calculated:", schoolsWithRisk.length);
console.log("Sample risk scores:", schoolsWithRisk.slice(0, 5).map(s => ({
  name: s.address?.split(' - ')[0],
  riskScore: s.riskScore,
  factors: s.riskFactors
})));

// ============================================================================
// APPLY FILTERS
// ============================================================================
// Filter schools based on user-selected school level, school type, EPA proximity, locale, and minimum risk score

const filteredSchools = schoolsWithRisk.filter(d => {
  const levelMatch = schoolLevelFilter.includes(d.schoolLevel);
  const ownershipMatch = ownershipFilter.includes(d.school_type);
  const epaMatch = 
    (epaFilter.includes("Near EPA sites") && d.nearEPA) ||
    (epaFilter.includes("Not near EPA sites") && !d.nearEPA);
  const localeMatch = localeFilter.includes(d.localeText);
  const riskMatch = d.riskScore >= minRiskScore;
  
  return levelMatch && ownershipMatch && epaMatch && localeMatch && riskMatch;
});

console.log("Filtered schools:", filteredSchools.length);
console.log("Sample filtered school coords:", filteredSchools.slice(0, 3).map(s => ({
  name: s.address?.split(' - ')[0],
  lat: s.lat,
  lon: s.lon,
  riskScore: s.riskScore
})));
```

<!-- ============================================================================ -->
<!-- SUMMARY PANEL -->
<!-- ============================================================================ -->
<!-- Display comprehensive statistics about filtered schools including:
     - Risk distribution (low/medium/high counts)
     - Enrollment statistics (total students, average per school, average risk)
     - Environment & demographics (EPA proximity, public/private school counts) -->

```js
// ============================================================================
// INTERACTIVE MAP
// ============================================================================
// Create Observable Plot map with:
// - Maine county boundaries
// - School locations as dots colored by risk score (green=low, yellow=medium, red=high)
// - Custom d3.geoAlbers projection rotated 15° clockwise
// - Color legend showing risk score scale

// Map with pointer interaction
console.log("Creating map with filteredSchools:", filteredSchools.length);

const map = Plot.plot({
  // MAP SIZE CONTROLS: Set the dimensions of the map canvas
  width: 700,   // Map width in pixels
  height: 400,  // Map height in pixels (reduced from 650 for more compact layout)
  
  projection: ({width, height}) => d3.geoAlbers()
    .rotate([75, 0])
    .center([0, 45])
    .translate([width / 2, height / 2])
    // MAP SIZE CONTROLS: fitExtent defines padding around the map content
    // Format: [[left, top], [right, bottom]] - currently 20px padding on all sides
    // FIT TO COUNTIES: Using counties instead of filteredSchools keeps the map stable
    // when filtering changes. This prevents unwanted zoom-in when few schools remain.
    .fitExtent([[20, 20], [width - 20, height - 20]], {
      type: "FeatureCollection",
      features: counties
    }),
  color: {
    type: "linear",
    domain: [0, 10],
    range: ["#28a745", "#ffc107", "#dc3545"],
    legend: true,
    label: "Closure Risk Score",
    // LEGEND POSITION CONTROL: Add left margin to prevent cutoff
    marginLeft: 40  // Shift legend to the right by 40px
  },
  marks: [
    Plot.geo(counties, {
      fill: "#f5f5f5",
      stroke: "#999",
      strokeWidth: 1
    }),
    // County labels at centroid of each county
    Plot.text(counties, Plot.geoCentroid({
      text: d => d.properties.name,
      fill: "#666",
      fontSize: 9,
      fontWeight: "500",
      stroke: "white",
      strokeWidth: 3,
      paintOrder: "stroke"
    })),
    Plot.dot(filteredSchools, {
      x: "lon",
      y: "lat",
      r: 5,
      fill: "riskScore",
      stroke: "#fff",
      strokeWidth: 1.5,
      // Make dots respond to pointer events
      pointerEvents: "all",
      cursor: "pointer"
    })
  ]
});

console.log("Map created:", map);
console.log("Map SVG element:", map.tagName);
console.log("Map has SVG child:", map.querySelector("svg"));
console.log("SVG viewBox:", map.querySelector("svg")?.getAttribute("viewBox"));
console.log("SVG width/height:", map.querySelector("svg")?.getAttribute("width"), map.querySelector("svg")?.getAttribute("height"));
console.log("Number of circles in map:", map.querySelectorAll("circle").length);

// ============================================================================
// ZOOM FUNCTIONALITY
// ============================================================================
// Apply d3.zoom to the map SVG with scale-invariant dot sizing
// (dots maintain constant visual size as user zooms in/out)

function zoom(chart) {
  // Find the main map SVG (not the legend)
  const svgs = chart.querySelectorAll("svg");
  let mapSvg = null;
  
  // The map SVG will be larger than the legend SVG
  for (const svg of svgs) {
    const width = parseFloat(svg.getAttribute("width"));
    if (width >= 500) { // Map is 500px or larger, legend is typically ~240px
      mapSvg = svg;
      break;
    }
  }
  
  if (!mapSvg) {
    console.error("Could not find map SVG!");
    return chart;
  }
  
  console.log("Found map SVG:", mapSvg.getAttribute("width"), "x", mapSvg.getAttribute("height"));
  
  // creates an intermediary layer which takes the transform
  const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
  for (const s of [...mapSvg.children]) g.appendChild(s);
  mapSvg.appendChild(g);
  
  // Find all circles (school dots) and store their original radius and stroke width
  const circles = g.querySelectorAll("circle");
  const originalRadii = Array.from(circles).map(c => parseFloat(c.getAttribute("r")));
  const originalStrokes = Array.from(circles).map(c => parseFloat(c.getAttribute("stroke-width")) || 0);
  
  // Find all text labels (county names) and store their original font size and stroke width
  const labels = g.querySelectorAll("text");
  const originalFontSizes = Array.from(labels).map(t => parseFloat(getComputedStyle(t).fontSize) || 9);
  const originalTextStrokes = Array.from(labels).map(t => parseFloat(t.getAttribute("stroke-width")) || 0);
  
  console.log("Found circles for zoom:", circles.length);
  console.log("Found labels for zoom:", labels.length);
  
  // Store current transform for tooltip positioning
  let currentTransform = d3.zoomIdentity;
  
  const zoomBehavior = d3
    .zoom()
    .on("zoom", ({ transform }) => {
      currentTransform = transform;
      g.setAttribute("transform", transform);
      // Scale down both radius and stroke width to keep them constant visual size
      circles.forEach((circle, i) => {
        circle.setAttribute("r", originalRadii[i] / transform.k);
        circle.setAttribute("stroke-width", originalStrokes[i] / transform.k);
      });
      // Scale down text labels to keep them constant visual size
      labels.forEach((label, i) => {
        label.style.fontSize = `${originalFontSizes[i] / transform.k}px`;
        if (originalTextStrokes[i] > 0) {
          label.setAttribute("stroke-width", originalTextStrokes[i] / transform.k);
        }
      });
    });
  
  d3.select(mapSvg).call(zoomBehavior);
  
  // Add tooltip handling that accounts for zoom
  const tooltip = d3.select("body").append("div")
    .style("position", "absolute")
    .style("background", "rgba(0, 0, 0, 0.8)")
    .style("color", "white")
    .style("padding", "8px 12px")
    .style("border-radius", "4px")
    .style("font-size", "14px")
    .style("pointer-events", "none")
    .style("opacity", 0)
    .style("z-index", 1000);
  
  circles.forEach((circle, i) => {
    circle.addEventListener("mouseenter", (e) => {
      const school = filteredSchools[i];
      if (school) {
        const tooltipText = `${school.address.split(" - ")[0]}<br>Risk Score: ${school.riskScore.toFixed(1)}/10<br>Click for details`;
        tooltip
          .style("opacity", 1)
          .html(tooltipText);
      }
    });
    
    circle.addEventListener("mousemove", (e) => {
      tooltip
        .style("left", (e.pageX + 10) + "px")
        .style("top", (e.pageY - 28) + "px");
    });
    
    circle.addEventListener("mouseleave", () => {
      tooltip.style("opacity", 0);
    });
  });
  
  return chart;
}

const zoomedMap = zoom(map);
console.log("Zoom applied to map");
console.log("ZoomedMap element:", zoomedMap);
console.log("ZoomedMap children count:", zoomedMap.children.length);
console.log("ZoomedMap has SVG:", zoomedMap.querySelector("svg"));

// ============================================================================
// DETAIL PANEL
// ============================================================================
// Create sidebar panel that displays detailed information when a school is clicked
// Includes: risk score, school profile, EPA sites, demographics, and trend charts

// Create detail panel container
const detailPanel = document.createElement("div");
detailPanel.id = "detail-panel";
detailPanel.className = "detail-panel";
detailPanel.style.maxHeight = "650px";
detailPanel.style.overflowY = "auto";

// Create a content wrapper inside the detail panel
const detailContent = document.createElement("div");
detailContent.id = "detail-content";
detailContent.innerHTML = `
  <div style="display: flex; align-items: center; justify-content: center; min-height: 400px;">
    <div style="text-align: center; color: #999;">
      <p style="font-size: 2.5rem; margin: 0;">📍</p>
      <p style="font-size: 0.85rem;">Click on a school to view details</p>
    </div>
  </div>
`;
detailPanel.appendChild(detailContent);

// Add close button to detail panel
const closeButton = document.createElement("button");
closeButton.innerHTML = "✕";
closeButton.style.cssText = "position: absolute; top: 0.5rem; right: 0.5rem; background: rgba(255,255,255,0.95); border: 1px solid #ddd; border-radius: 50%; width: 28px; height: 28px; cursor: pointer; font-size: 1.2rem; line-height: 1; color: #666; transition: all 0.2s; z-index: 10; display: flex; align-items: center; justify-content: center;";
closeButton.onmouseover = () => {
  closeButton.style.background = "#f5f5f5";
  closeButton.style.color = "#333";
  closeButton.style.borderColor = "#999";
};
closeButton.onmouseout = () => {
  closeButton.style.background = "rgba(255,255,255,0.95)";
  closeButton.style.color = "#666";
  closeButton.style.borderColor = "#ddd";
};
closeButton.onclick = (e) => {
  e.stopPropagation();
  detailPanel.style.right = "calc(-280px - 2rem)"; // Slide completely off-screen
};
detailPanel.appendChild(closeButton);

// ============================================================================
// RENDER SCHOOL DETAILS FUNCTION
// ============================================================================
// Populates the detail panel with comprehensive school information including:
// - School name and address
// - Risk score with color-coded background and contributing factors
// - School profile (type, status, enrollment, grades)
// - Nearby EPA brownfield sites (if any)
// - Census tract demographics
// - Time series charts comparing enrollment and child population trends

function renderSchoolDetails(school) {
  const nearbySites = epaSites
    .map(site => ({
      ...site,
      distance: distance(school.lat, school.lon, site.lat, site.lon)
    }))
    .filter(site => site.distance < 2)
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 3);

  // Get enrollment history for this school
  const enrollmentData = school.ncessch ? 
    enrollmentHistory.filter(d => d.ncessch === school.ncessch).sort((a, b) => a.year - b.year) : 
    [];

  // Get child population time series for this school's tract
  const tractData = school.geoid ? 
    childPop.filter(d => d.geoid === school.geoid).sort((a, b) => a.year - b.year) : 
    [];

  // Calculate trends
  const enrollTrend = enrollmentData.length > 1 ? 
    ((enrollmentData[enrollmentData.length - 1].enrollment - enrollmentData[0].enrollment) / enrollmentData[0].enrollment * 100) : 
    null;

  const childPopTrend = tractData.length > 0 ? 
    ((tractData[tractData.length - 1].pop_under_5 - tractData[0].pop_under_5) / tractData[0].pop_under_5 * 100) : 
    null;

  let epaSitesHTML = '';
  if (nearbySites.length > 0) {
    const sitesListHTML = nearbySites.map(site => `
      <div style="font-size: 0.65em; margin-top: 0.15rem; line-height: 1.3;">
        ${site.site_name} <span style="color: #888;">(${site.distance.toFixed(1)} mi)</span>
      </div>
    `).join('');
    
    epaSitesHTML = `
      <div style="background: #fff3cd; padding: 0.5rem; border-radius: 4px; border-left: 3px solid #dc3545; margin-top: 0.5rem;">
        <strong style="font-size: 0.7rem;">⚠️ ${nearbySites.length} EPA Site${nearbySites.length > 1 ? 's' : ''}</strong>
        ${sitesListHTML}
      </div>
    `;
  }

  // let lunchProgramHTML = '';
  // if (school.school_type === "Public" && school.total_frl) {
  //   lunchProgramHTML = `
  //     <div class="detail-section">
  //       <h4>Lunch Program</h4>
  //       <table class="detail-table">
  //         <tr><th>Free/Reduced</th><td>${school.total_frl.toLocaleString()}</td></tr>
  //         <tr><th>FRL Rate</th><td>${school.enrollment ? ((school.total_frl / school.enrollment) * 100).toFixed(1) : "N/A"}%</td></tr>
  //         <tr><th>Teachers (FTE)</th><td>${school.fte || "N/A"}</td></tr>
  //       </table>
  //     </div>
  //   `;
  // }

  // Create combined trend chart
  let trendChartHTML = '';
  if (enrollmentData.length > 1 && tractData.length > 1) {
    // Normalize both datasets to percentages (base year = 100)
    const enrollmentNormalized = enrollmentData.map((d, i) => ({
      year: d.year,
      value: (d.enrollment / enrollmentData[0].enrollment) * 100,
      series: "Enrollment"
    }));
    
    const popNormalized = tractData.map((d, i) => ({
      year: d.year,
      value: (d.pop_under_5 / tractData[0].pop_under_5) * 100,
      series: "Children <5"
    }));
    
    const combinedData = [...enrollmentNormalized, ...popNormalized];
    
    // Determine if converging or diverging
    const enrollmentFirst = enrollmentNormalized[0].value;
    const enrollmentLast = enrollmentNormalized[enrollmentNormalized.length - 1].value;
    const popFirst = popNormalized[0].value;
    const popLast = popNormalized[popNormalized.length - 1].value;
    
    // Calculate gap in percentage points (not ratio to avoid division by zero)
    const initialGap = Math.abs(enrollmentFirst - popFirst);
    const finalGap = Math.abs(enrollmentLast - popLast);
    const isConverging = finalGap < initialGap;
    const gapChange = (finalGap - initialGap).toFixed(1); // Absolute change in percentage points
    
    // Determine trend direction
    const enrollmentTrend = enrollmentLast > enrollmentFirst ? "Increasing" : "Decreasing";
    const popTrend = popLast > popFirst ? "Increasing" : "Decreasing";
    
    const chart = Plot.plot({
      width: 260,
      height: 130,
      marginTop: 25,
      marginRight: 50,
      marginBottom: 25,
      marginLeft: 35,
      x: {label: null, tickFormat: d => d.toString()},
      y: {label: "Index (base year = 100)", grid: true, tickSize: 3},
      color: {
        domain: ["Enrollment", "Children <5"],
        range: ["#007bff", "#28a745"],
        legend: true
      },
      marks: [
        Plot.lineY(combinedData, {x: "year", y: "value", stroke: "series", strokeWidth: 2}),
        Plot.dot(combinedData, {x: "year", y: "value", fill: "series", r: 2.5}),
        // Simple trend lines (first to last point)
        Plot.line([enrollmentNormalized[0], enrollmentNormalized[enrollmentNormalized.length - 1]], {x: "year", y: "value", stroke: "#007bff", strokeOpacity: 0.4, strokeWidth: 2, strokeDasharray: "5,5"}),
        Plot.line([popNormalized[0], popNormalized[popNormalized.length - 1]], {x: "year", y: "value", stroke: "#28a745", strokeOpacity: 0.4, strokeWidth: 2, strokeDasharray: "5,5"}),
        Plot.ruleY([100], {stroke: "#ccc", strokeDasharray: "4,4"}),
        // Add percentage change labels at the end of each line
        Plot.text([{
          x: enrollmentNormalized[enrollmentNormalized.length - 1].year,
          y: enrollmentNormalized[enrollmentNormalized.length - 1].value,
          label: `${enrollTrend > 0 ? '+' : ''}${enrollTrend.toFixed(1)}%`
        }], {x: "x", y: "y", text: "label", fill: "#007bff", fontSize: 10, dx: 15, fontWeight: "bold"}),
        Plot.text([{
          x: popNormalized[popNormalized.length - 1].year,
          y: popNormalized[popNormalized.length - 1].value,
          label: `${childPopTrend > 0 ? '+' : ''}${childPopTrend.toFixed(1)}%`
        }], {x: "x", y: "y", text: "label", fill: "#28a745", fontSize: 10, dx: 15, fontWeight: "bold"})
      ]
    });
    
    const trendIcon = isConverging ? "↔️" : "↕️";
    const trendText = isConverging ? "Converging" : "Diverging";
    const trendColor = isConverging ? "#28a745" : "#dc3545";
    
    trendChartHTML = `
      <div class="detail-section">
        <h4>
          Enrollment vs. Child Population 
          <span style="color: ${trendColor}; font-size: 0.9em;">${trendIcon} ${trendText}</span>
        </h4>
        ${chart.outerHTML}
      </div>
    `;
  } else if (enrollmentData.length > 1) {
    const chart = Plot.plot({
      width: 260,
      height: 100,
      marginTop: 15,
      marginRight: 10,
      marginBottom: 25,
      marginLeft: 35,
      x: {label: null, tickFormat: d => d.toString()},
      y: {label: "Students", grid: true, tickSize: 3},
      marks: [
        Plot.lineY(enrollmentData, {x: "year", y: "enrollment", stroke: "#007bff", strokeWidth: 2}),
        Plot.dot(enrollmentData, {x: "year", y: "enrollment", fill: "#007bff", r: 2.5}),
        Plot.ruleY([0])
      ]
    });
    trendChartHTML = `
      <div class="detail-section">
        <h4>Enrollment Trend ${enrollTrend !== null ? `(${enrollTrend > 0 ? '+' : ''}${enrollTrend.toFixed(1)}%)` : ''}</h4>
        ${chart.outerHTML}
      </div>
    `;
  } else if (tractData.length > 1) {
    const chart = Plot.plot({
      width: 260,
      height: 100,
      marginTop: 15,
      marginRight: 10,
      marginBottom: 25,
      marginLeft: 35,
      x: {label: null, tickFormat: d => d.toString()},
      y: {label: "Children <5", grid: true, tickSize: 3},
      marks: [
        Plot.lineY(tractData, {x: "year", y: "pop_under_5", stroke: "#28a745", strokeWidth: 2}),
        Plot.dot(tractData, {x: "year", y: "pop_under_5", fill: "#28a745", r: 2.5}),
        Plot.ruleY([0])
      ]
    });
    trendChartHTML = `
      <div class="detail-section">
        <h4>Area Children Under 5 ${childPopTrend !== null ? `(${childPopTrend > 0 ? '+' : ''}${childPopTrend.toFixed(1)}%)` : ''}</h4>
        ${chart.outerHTML}
      </div>
    `;
  }

  // Update the content wrapper (not the whole panel, to preserve the close button)
  const detailContent = detailPanel.querySelector('#detail-content');
  detailContent.innerHTML = `
    <h3 style="margin-top: 0; color: #333; border-bottom: 2px solid #007bff; padding-bottom: 0.3rem; font-size: 0.8rem;">
      ${school.address.split(' - ')[0]}
    </h3>
    <p style="font-size: 0.65em; color: #666; margin: 0.15rem 0 0.5rem 0;">
      ${school.address.split(' - ')[1] || ''}
    </p>
    
    <div class="detail-section" style="background: ${school.riskScore > 7 ? '#ffebee' : school.riskScore > 4 ? '#fff3e0' : '#e8f5e9'}; padding: 0.5rem; border-radius: 4px; margin-top: 0.3rem;">
      <h4 style="margin: 0 0 0.3rem 0; color: ${school.riskScore > 7 ? '#c62828' : school.riskScore > 4 ? '#ef6c00' : '#2e7d32'}; font-size: 0.7rem;">
        Closure Risk Score: ${school.riskScore.toFixed(1)}/10
      </h4>
      ${school.riskFactors.length > 0 ? `
        <div style="font-size: 0.65em; color: #666;">
          <strong>Risk Factors:</strong>
          <ul style="margin: 0.15rem 0; padding-left: 1rem; line-height: 1.3;">
            ${school.riskFactors.map(f => `<li style="margin-bottom: 0.05rem;">${f}</li>`).join('')}
          </ul>
        </div>
      ` : '<p style="font-size: 0.65em; color: #666; margin: 0;">No significant risk factors identified.</p>'}
    </div>

    ${trendChartHTML} 
    ${epaSitesHTML}

    <div class="detail-section" style="margin-top: 0.4rem; padding-top: 0.3rem;">
      <h4 style="margin-bottom: 0.3rem;">School Profile</h4>
      <table class="detail-table">
        <tr><th>Type</th><td>${school.school_type}</td></tr>
        <tr><th>Status</th><td>${formatStatus(school.status)}</td></tr>
        <tr><th>Enrollment</th><td>${school.enrollment?.toLocaleString() || "N/A"}</td></tr>
        <tr><th>Grades</th><td>${school.grade_low || "?"}-${school.grade_high || "?"}</td></tr>
        <tr><th>Locale</th><td>${school.localeText || "N/A"}</td></tr>
      </table>
    </div>
        
    <div class="detail-section" style="margin-top: 0.4rem; padding-top: 0.3rem;">
      <h4 style="margin-bottom: 0.3rem;">Demographics</h4>
      <table class="detail-table">
        <tr><th>Median Income</th><td>$${school.income?.toLocaleString() || "N/A"}</td></tr>
        <tr><th>Poverty Rate</th><td>${school.poverty_rate?.toFixed(1) || "N/A"}%</td></tr>
        <tr><th>Unemployment</th><td>${school.unemployment?.toFixed(1) || "N/A"}%</td></tr>
        <tr><th>Bachelor's Degree</th><td>${school.bachelors?.toFixed(1) || "N/A"}%</td></tr>
      </table>
    </div>
  `;
}
//    ${lunchProgramHTML}

// ============================================================================
// CLICK EVENT HANDLER
// ============================================================================
// Listen for clicks on school dots to display details and slide in the panel

// Listen to Plot's pointer events on the SVG
zoomedMap.addEventListener("click", (event) => {
  // Find which school dot was clicked by checking the circles
  const circles = zoomedMap.querySelectorAll("circle");
  const clickedCircle = event.target;
  
  if (clickedCircle.tagName === "circle") {
    const index = Array.from(circles).indexOf(clickedCircle);
    if (index >= 0 && index < filteredSchools.length) {
      renderSchoolDetails(filteredSchools[index]);
      // Slide in the detail panel
      detailPanel.style.right = "1rem";
    }
  }
});

// ============================================================================
// LAYOUT CONTAINER
// ============================================================================
// Create overlay layout with detail panel positioned on top of the map
// The panel starts hidden off-screen and slides in when a school is clicked

// Create outer wrapper that allows panel to extend beyond map
const outerWrapper = document.createElement("div");
// CONTAINER WIDTH CONTROL: Outer wrapper width (map width + borders)
// Current: 706px = 700px map + 6px (3px border on each side)
// To adjust: change to match your map width + border thickness
outerWrapper.style.cssText = "position: relative; width: 706px; min-height: 656px;";

// Create inner container for the map with border
const mapContainer = document.createElement("div");
// CONTAINER WIDTH CONTROL: Inner container dimensions
// Width: Should match the map width (currently 500px in Plot.plot)
// Height: Should match the map height (currently 580px in Plot.plot)
// BORDER CONTROL: Customize the border around the map container
//   - border: 3px solid #007bff (3px width, solid style, blue color)
//   - border-radius: 8px (rounded corners)
//   - box-shadow: 0 2px 8px rgba(0,0,0,0.1) (shadow effect)
// To remove border: change "border: 3px solid #007bff" to "border: none"
// To change border color: replace #007bff with your color
// To change border width: replace 3px with desired width (affects outer wrapper too)
mapContainer.style.cssText = "position: relative; width: 700px; height: 650px; border: none; border-radius: 8px; overflow: hidden;";

// ============================================================================
// SUMMARY STATISTICS CALCULATION
// ============================================================================
// Pre-calculate all summary statistics for the filtered schools
const summaryStats = {
  total: filteredSchools.length,
  elementary: filteredSchools.filter(s => s.schoolLevel === "Elementary").length,
  middle: filteredSchools.filter(s => s.schoolLevel === "Middle").length,
  high: filteredSchools.filter(s => s.schoolLevel === "High").length,
  lowRisk: filteredSchools.filter(s => s.riskScore <= 3.3).length,
  mediumRisk: filteredSchools.filter(s => s.riskScore > 3.3 && s.riskScore <= 6.6).length,
  highRisk: filteredSchools.filter(s => s.riskScore > 6.6).length,
  totalStudents: d3.sum(filteredSchools, s => s.enrollment || 0),
  avgStudents: Math.round(d3.mean(filteredSchools, s => s.enrollment || 0) || 0),
  avgRisk: (d3.mean(filteredSchools, s => s.riskScore) || 0).toFixed(1),
  nearEPA: filteredSchools.filter(s => s.nearEPA).length,
  publicSchools: filteredSchools.filter(s => s.school_type === "Public").length,
  privateSchools: filteredSchools.filter(s => s.school_type === "Private").length
};

console.log("Summary Statistics:", summaryStats);

// ============================================================================
// RENDER SUMMARY PANEL
// ============================================================================
// Create and display the summary panel with statistics

// Create summary panel
const summaryPanel = document.createElement("div");
summaryPanel.style.cssText = "background: white; border: none; border-radius: 6px; padding: 0.75rem; margin-bottom: 1rem;";

// Create header div for title/label at top of map
const mapHeader = document.createElement("div");
mapHeader.style.cssText = "padding: 1rem; background: white; border-bottom: 1px solid #e9ecef;";
mapHeader.innerHTML = 
`
  <h1 style="margin: 0 0 0.25rem 0; color: #007bff; font-size: 1rem; border-bottom: 2px solid #007bff; padding-bottom: 0.3rem;">
  Maine School Closure Risk (${summaryStats.total} schools)
  </h1>
  <p style="margin: 0 0 0.5rem 0; font-size: 0.8rem; color: #666; font-style: italic;">
    💡 Click on any school dot to view detailed information
  </p>
  
  <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
    <div>
      <h4 style="margin: 0 0 0.4rem 0; color: #495057; font-size: 0.85rem; font-weight: 600;">
        🎯 Risk Distribution
      </h4>
      <div style="font-size: 0.8rem; line-height: 1.4; color: #495057;">
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span style="color: #28a745;">● Low (0-3.3)</span>
          <strong>${summaryStats.lowRisk}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span style="color: #ffc107;">● Medium (3.4-6.6)</span>
          <strong>${summaryStats.mediumRisk}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0;">
          <span style="color: #dc3545;">● High (6.7-10)</span>
          <strong>${summaryStats.highRisk}</strong>
        </div>
      </div>
    </div>
    
    <div>
      <h4 style="margin: 0 0 0.4rem 0; color: #495057; font-size: 0.85rem; font-weight: 600;">
        👥 Enrollment Stats
      </h4>
      <div style="font-size: 0.8rem; line-height: 1.4; color: #495057;">
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span>Total Students</span>
          <strong>${summaryStats.totalStudents.toLocaleString()}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span>Average per School</span>
          <strong>${summaryStats.avgStudents.toLocaleString()}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0;">
          <span>Avg Risk Score</span>
          <strong>${summaryStats.avgRisk}</strong>
        </div>
      </div>
    </div>
    
    <div>
      <h4 style="margin: 0 0 0.4rem 0; color: #495057; font-size: 0.85rem; font-weight: 600;">
        🌍 Classification
      </h4>
      <div style="font-size: 0.8rem; line-height: 1.4; color: #495057;">
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span>Near EPA Sites</span>
          <strong>${summaryStats.nearEPA}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0; border-bottom: 1px solid #e9ecef;">
          <span>Public Schools</span>
          <strong>${summaryStats.publicSchools}</strong>
        </div>
        <div style="display: flex; justify-content: space-between; padding: 0.15rem 0;">
          <span>Private Schools</span>
          <strong>${summaryStats.privateSchools}</strong>
        </div>
      </div>
    </div>
  </div>
`;

// Add header and map to container
mapContainer.appendChild(mapHeader);
mapContainer.appendChild(zoomedMap);

// Add map container to outer wrapper
outerWrapper.appendChild(mapContainer);

// ============================================================================
// ALGORITHM TOOLTIP
// ============================================================================
// Create tooltip button with algorithm explanation

const maxPossibleScore = enrollmentDeclineWeight + childPopDeclineWeight + 
                         povertyWeight + educationWeight + unemploymentWeight;

// Create tooltip container
const algorithmTooltip = document.createElement("div");
algorithmTooltip.style.cssText = "position: absolute; bottom: 1rem; left: 1rem; z-index: 999;";

// Create tooltip button
const tooltipButton = document.createElement("button");
tooltipButton.innerHTML = "ℹ️";
tooltipButton.title = "View Risk Algorithm";
tooltipButton.style.cssText = "width: 36px; height: 36px; border-radius: 50%; background: rgba(255,255,255,0.95); border: 2px solid #007bff; cursor: pointer; font-size: 1.3rem; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.2); transition: all 0.2s;";

// Create tooltip content (hidden by default)
const tooltipContent = document.createElement("div");
tooltipContent.style.cssText = "position: absolute; bottom: 45px; left: 0; background: white; border: 2px solid #007bff; border-radius: 8px; padding: 1rem; width: 400px; max-height: 500px; overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.3); display: none;";
tooltipContent.innerHTML = `
  <h4 style="margin: 0 0 0.75rem 0; color: #007bff; font-size: 1rem; border-bottom: 2px solid #007bff; padding-bottom: 0.5rem;">
    📊 School Closure Risk Algorithm
  </h4>
  
  <div style="background: #f8f9fa; padding: 0.75rem; border-radius: 6px; margin-bottom: 0.75rem;">
    <p style="margin: 0 0 0.5rem 0; font-weight: 600; font-size: 0.85rem; color: #495057;">Normalized Risk Score (0-10):</p>
    <div style="font-family: 'Courier New', monospace; font-size: 0.75rem; line-height: 1.6; color: #212529;">
      <strong>Raw Score</strong> = <br>
      &nbsp;&nbsp;(<span style="color: #dc3545;">Enrollment Decline</span> × <strong>${enrollmentDeclineWeight.toFixed(1)}</strong>) + <br>
      &nbsp;&nbsp;(<span style="color: #dc3545;">Child Pop Decline</span> × <strong>${childPopDeclineWeight.toFixed(1)}</strong>) + <br>
      &nbsp;&nbsp;(<span style="color: #ffc107;">Poverty Rate</span> × <strong>${povertyWeight.toFixed(1)}</strong>) + <br>
      &nbsp;&nbsp;(<span style="color: #ffc107;">Low Education</span> × <strong>${educationWeight.toFixed(1)}</strong>) + <br>
      &nbsp;&nbsp;(<span style="color: #ffc107;">Unemployment</span> × <strong>${unemploymentWeight.toFixed(1)}</strong>)
      <br><br>
      <strong>Normalized</strong> = (Raw / <strong>${maxPossibleScore.toFixed(1)}</strong>) × 10
    </div>
  </div>
  
  <div style="font-size: 0.8rem; line-height: 1.5; color: #495057;">
    <p style="margin: 0 0 0.4rem 0; font-weight: 600;">Factor Definitions:</p>
    <p style="margin: 0 0 0.3rem 0; padding-left: 0.5rem;"><strong style="color: #dc3545;">Enrollment Decline:</strong> 1 if >10% drop, else 0</p>
    <p style="margin: 0 0 0.3rem 0; padding-left: 0.5rem;"><strong style="color: #dc3545;">Child Pop Decline:</strong> 1 if >5% drop in tract's under-5 pop, else 0</p>
    <p style="margin: 0 0 0.3rem 0; padding-left: 0.5rem;"><strong style="color: #ffc107;">Poverty Rate:</strong> 0-1 normalized (15-35% range)</p>
    <p style="margin: 0 0 0.3rem 0; padding-left: 0.5rem;"><strong style="color: #ffc107;">Low Education:</strong> 0-1 normalized (5-20% bachelor's)</p>
    <p style="margin: 0; padding-left: 0.5rem;"><strong style="color: #ffc107;">Unemployment:</strong> 0-1 normalized (5-15% range)</p>
  </div>
`;

// Show/hide tooltip on hover
tooltipButton.onmouseenter = () => {
  tooltipContent.style.display = "block";
  tooltipButton.style.background = "#007bff";
  tooltipButton.style.transform = "scale(1.1)";
};

algorithmTooltip.onmouseleave = () => {
  tooltipContent.style.display = "none";
  tooltipButton.style.background = "rgba(255,255,255,0.95)";
  tooltipButton.style.transform = "scale(1)";
};

// Assemble tooltip
algorithmTooltip.appendChild(tooltipButton);
algorithmTooltip.appendChild(tooltipContent);

// Add tooltip to outer wrapper
outerWrapper.appendChild(algorithmTooltip);

// Style detail panel as an overlay that slides in from the right
detailPanel.style.position = "absolute";
detailPanel.style.top = "1rem";
detailPanel.style.width = "280px";
detailPanel.style.maxHeight = "628px"; // 650px - 2rem for top margin
detailPanel.style.zIndex = "1000";
detailPanel.style.boxShadow = "0 4px 12px rgba(0,0,0,0.3)";
detailPanel.style.transition = "right 0.3s ease-out"; // Animate the right position instead
detailPanel.style.right = "calc(-280px - 2rem)"; // Start completely hidden off-screen (panel width + margins)

// Add panel to outer wrapper (not map container)
outerWrapper.appendChild(detailPanel);

// Add overflow hidden to a wrapper div to hide the panel when off-screen
const displayWrapper = document.createElement("div");
displayWrapper.style.cssText = "overflow: hidden; width: 706px;";
displayWrapper.appendChild(outerWrapper);

console.log("Container created with children:", outerWrapper.children.length);
console.log("ZoomedMap dimensions:", zoomedMap.getBBox ? zoomedMap.getBBox() : "N/A");

// Return the display wrapper to display it
display(displayWrapper);
```

```js
import * as Inputs from "npm:@observablehq/inputs";

// ============================================================================
// FILTER CONTROLS
// ============================================================================
// Checkboxes to filter schools by type and EPA site proximity

const schoolLevelFilter = view(Inputs.checkbox(
  ["Elementary", "Middle", "High", "Multi-Level", "Other"],
  {label: "School Level", value: ["Elementary", "Middle", "High", "Multi-Level", "Other"]}
));

const ownershipFilter = view(Inputs.checkbox(
  ["Public", "Private"],
  {label: "School Type", value: ["Public", "Private"]}
));

const epaFilter = view(Inputs.checkbox(
  ["Near EPA sites", "Not near EPA sites"],
  {label: "Environmental Status", value: ["Near EPA sites", "Not near EPA sites"]}
));

const localeFilter = view(Inputs.checkbox(
  [
    "City: Large", "City: Midsize", "City: Small",
    "Suburb: Large", "Suburb: Midsize", "Suburb: Small",
    "Town: Fringe", "Town: Distant", "Town: Remote",
    "Rural: Fringe", "Rural: Distant", "Rural: Remote"
  ],
  {
    label: "Locale (Urban-Rural Setting)",
    value: [
      "City: Large", "City: Midsize", "City: Small",
      "Suburb: Large", "Suburb: Midsize", "Suburb: Small",
      "Town: Fringe", "Town: Distant", "Town: Remote",
      "Rural: Fringe", "Rural: Distant", "Rural: Remote"
    ]
  }
));

const minRiskScore = view(Inputs.range([0, 10], {
  label: "Minimum Risk Score",
  step: 0.5,
  value: 0
}));

// ============================================================================
// RISK ALGORITHM WEIGHT CONTROLS
// ============================================================================
// These range sliders allow users to configure the importance of each risk 
// factor in the school closure risk algorithm. Values range from 0-10.

const enrollmentDeclineWeight = view(Inputs.range([0, 10], {
  label: "Enrollment Decline Weight",
  step: 0.5,
  value: 10
}));

const childPopDeclineWeight = view(Inputs.range([0, 10], {
  label: "Child Population Decline Weight",
  step: 0.5,
  value: 10
}));

const povertyWeight = view(Inputs.range([0, 10], {
  label: "Poverty Rate Weight",
  step: 0.5,
  value: 0
}));

const educationWeight = view(Inputs.range([0, 10], {
  label: "Low Education Weight",
  step: 0.5,
  value: 0
}));

const unemploymentWeight = view(Inputs.range([0, 10], {
  label: "Unemployment Weight",
  step: 0.5,
  value: 0
}));
```

<style>
/* Observable Inputs Styling - enhances appearance without breaking reactivity */

/* Input labels */
form label {
  font-weight: 600;
  color: #333;
  font-size: 0.8rem;
  margin-bottom: 0.1rem;
  display: block;
  line-height: 1.2;
}

/* Range sliders */
input[type="range"] {
  width: 100%;
  height: 3px;
  border-radius: 2px;
  background: linear-gradient(to right, #e9ecef 0%, #007bff 100%);
  outline: none;
  -webkit-appearance: none;
  margin: 0.1rem 0 0.2rem 0;
}

input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #007bff;
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(0,0,0,0.2);
  transition: all 0.2s;
}

input[type="range"]::-webkit-slider-thumb:hover {
  background: #0056b3;
  transform: scale(1.1);
}

input[type="range"]::-moz-range-thumb {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #007bff;
  cursor: pointer;
  border: none;
  box-shadow: 0 1px 2px rgba(0,0,0,0.2);
  transition: all 0.2s;
}

input[type="range"]::-moz-range-thumb:hover {
  background: #0056b3;
  transform: scale(1.1);
}

/* Checkbox groups */
form div[style*="display: flex"] {
  gap: 0.25rem;
  flex-wrap: wrap;
  line-height: 1.2;
}

/* Individual checkboxes */
input[type="checkbox"] {
  width: 13px;
  height: 13px;
  cursor: pointer;
  accent-color: #007bff;
  margin: 0;
}

/* Checkbox labels */
form label[style*="display: inline-flex"] {
  font-weight: 400;
  font-size: 0.75rem;
  color: #495057;
  gap: 0.25rem;
  align-items: center;
  cursor: pointer;
  padding: 0.1rem 0.3rem;
  border-radius: 3px;
  transition: background-color 0.2s;
  margin: 0;
  line-height: 1.2;
}

form label[style*="display: inline-flex"]:hover {
  background-color: #f8f9fa;
}

/* Form spacing */
form {
  margin-bottom: 0.5rem;
  padding: 0.35rem 0.5rem;
  background: white;
  border-radius: 4px;
  border: 1px solid #e9ecef;
}

/* Range input value display */
output {
  font-weight: 600;
  color: #007bff;
  font-size: 0.8rem;
}

.detail-panel {
  background: white;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 0.65rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.detail-section {
  margin-top: 0.5rem;
  padding-top: 0.35rem;
  border-top: 1px solid #f0f0f0;
}

.detail-section:first-of-type {
  border-top: none;
  padding-top: 0;
}

.detail-section h4 {
  font-size: 0.7rem;
  color: #555;
  margin: 0 0 0.35rem 0;
  font-weight: 600;
}

.detail-table {
  width: 100%;
  font-size: 0.65rem;
  line-height: 1.3;
}

.detail-table th {
  text-align: left;
  color: #666;
  font-weight: 500;
  padding: 0.15rem 0;
  width: 55%;
}

.detail-table td {
  text-align: right;
  font-weight: 600;
  padding: 0.15rem 0;
}

.detail-table tr:not(:last-child) {
  border-bottom: 1px solid #f5f5f5;
}
</style>
