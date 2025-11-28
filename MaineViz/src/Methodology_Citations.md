---
title: Methodology, Data Sources, and Citations
---

# Data Sources and Methodology

This page documents the data sources, tools, and analytical methods used to identify patterns in Maine school closures and assess which schools may be at risk.

---

## Methodology

### Analytical Approach

Our analysis identifies patterns in Maine school closures by examining:

- **Historical closure data**: Where and when schools have closed
- **Building characteristics**: Age, size, and location of school facilities
- **Enrollment trends**: Changes in student populations over time
- **Economic context**: Construction costs and funding availability
- **Geographic patterns**: Rural vs. urban distributions

By mapping these factors, we identify common characteristics among closed schools and highlight open schools that share similar profiles.

### Tools & Technologies

- **DuckDB**: Data processing, cleaning, and analysis  (used in the beginning to see large files)
- **Observable Framework**: Interactive web-based visualization platform
- **GeoJSON**: Geographic data format for mapping school locations
- **JavaScript/D3.js**: Custom visualizations and interactivity

---

### Key Visualizations

**1. Maine School Closure Map**

Interactive map displaying:
-
-
-
-


**2. The How**
Visuals:
- Number of school closures by year
- Trend analysis showing acceleration in recent years

---

# Data Sources

## National Center for Education Statistics (NCES)

**NCES Education Demographic and Geographic Estimates (EDGE) - School Locations**
- URL: https://nces.ed.gov/programs/edge/Geographic/SchoolLocations
- Coverage: 2015-2016 through 2023-2024 school years
- Includes: Geographic data for public and private schools
- Updated: Annually

**NCES Common Core of Data (CCD) - Public School Data**
- URL: https://nces.ed.gov/ccd/
- Includes: School names, addresses, enrollment, grade levels, operational status
- Updated: Annually

**NCES Private School Universe Survey (PSS) - Private School Data**
- URL: https://nces.ed.gov/surveys/pss/
- Includes: School names, addresses, enrollment, grade levels, religious affiliation
- Updated: Biennially (every 2 years)

**NCES Open GIS Data - Public School Locations 2023-24**
- URL: https://nces.ed.gov/opengis/rest/services/K12_School_Locations/EDGE_GEOCODE_PUBLICSCH_2324/MapServer
- Map Service ID: 0
- Format: GIS web service for direct mapping integration

**School & District Navigator**
- URL: https://nces.ed.gov/ccd/schoolmap/
- Used for: Cross-referencing school locations and verifying data accuracy

## Maine Department of Education**
**Summary of Maine School Building Inventory**
- URL: https://www.maine.gov/doe/sites/maine.gov.doe/files/inline-files/Governors%20Commission%20-%20School%20Facility%20Inventory%20Summary%20Report%20-%201.30.2025.pdf
- Includes:
- Used for:
**Maine Department of Education Fiscal Year 2024-2025 State Subsidy Allocation**
- URL: 
- 
- Used for: 

**Maine DOE Data Warehouse**
- URL: https://www.maine.gov/doe/data-reporting/warehouse
- Includes: State-specific school information, district boundaries, enrollment trends
- Used for: State-level context and verification of NCES data

**Maine Open and Closed Schools Database**
- URL: https://neo.maine.gov/DOE/neo/Supersearch/ContactSearch/SearchByOpenAndClosedSchools
- Format: Excel spreadsheet (downloaded)
- Provides: Comprehensive list of closed schools with closure dates
- Note: Critical primary source for identifying closed schools

## Geographic Reference Data

**Maine Town and Townships Boundary Polygons**
- URL: https://maine.hub.arcgis.com/datasets/maine::maine-town-and-townships-boundary-polygons-feature-1/explore
- Format: GeoJSON/Shapefile
- Used for: Municipal boundary overlays and rural/urban classification

## Secondary Sources: Economic & Policy Context
**Essential Programs Services Formula**
- URL: https://themainemonitor.org/essential-programs-services-formula/
- Key data:
- Used for: 

**Governor's Commission on School Construction Interim Summary** (April 15, 2025)
- URL: https://www.maine.gov/doe/sites/maine.gov.doe/files/inline-files/Governors%20Commission%20-%20School%20Construction%20Interim%20Summary%20-%204.18.2025.pdf
- Key data: $11 billion total infrastructure need, construction cost trends, funding gap analysis
- Used for: Economic context in narrative

**Why is Building and Renovating Schools So Expensive?** (Central Maine, September 2024)
- URL: https://www.centralmaine.com/2024/09/22/why-is-building-and-renovating-schools-so-expensive/
- Key data: Construction costs rose from $270/sq ft (2015) to $661/sq ft (2024)
- Used for: Cost escalation visualization and narrative context

**Maine School Building Renovation Expenses** (News Center Maine)
- URL: https://www.newscentermaine.com/article/news/regional/the-maine-monitor/maine-school-building-renovating-expenses-construction-cost/97-2b559e74-d316-4e26-89b5-889a0e85df3d
- Provides: Additional construction cost context and case studies
- Used for: Supporting narrative on economic pressures

**$156 Million Middle School Under Construction** (Maine Monitor, July 2025)
- URL: https://themainemonitor.org/windham-156-million-dollar-school/
- Key data: State funding success rate (9 of 74 applicants), project cost examples
- Used for: Funding competition context

**Maine Forms Commission to Address Aging Infrastructure** (News Center Maine)
- URL: https://www.newscentermaine.com/article/news/education/maine-forms-commission-address-aging-school-infrastructure-crisis/97-f8e82ae0-7989-4770-a613-387c6cafb25f
- Key data: $580 million invested since 2019, ongoing demand exceeding resources
- Used for: Policy context and state response

**Bill to Add Hotel Sales Tax for School Construction** (News Center Maine)
- URL: https://www.newscentermaine.com/article/news/education/bill-would-add-hotel-sales-tax-fund-school-construction/97-e1f1449a-36af-4171-9413-503087e4d517
- Provides: Funding formula inequities, rural vs. urban disparities
- Used for: Understanding structural barriers facing rural communities

** Portland Press Herald: 5 Takeaways from our REporting on Maine's School Construction Backlog
- URL: https://www.pressherald.com/2025/10/02/5-takeaways-from-our-reporting-on-maines-school-construction-backlog/
- Used for:

## Supplementary Research: Individual School Closures

The following sources were used to verify closure dates, fill data gaps, and provide case study context for specific schools:

- **Maine Girls Academy closure**  
  https://www.newscentermaine.com/article/news/local/end-of-an-era-maine-girls-academy-closing-for-good/97-571384933

- **Catherine McAuley High School**  
  https://www.findingschool.com/catherine-mcauley-high-school

- **Bangor Hilltop School**  
  https://bangorhilltopschool.com/

- **Cocoons Day School**  
  https://www.cocoonsdayschool.org/

- **School Around Us Community**  
  https://www.schoolaroundus.org/community

- **MSAD 49 Albion Elementary School**  
  https://www.msad49.org/o/aes

- **Clinton and Benton School History**  
  https://townline.org/up-and-down-the-kennebec-valley-clinton-and-benton-school/

- **Juniper Hill School**  
  https://www.juniperhillschool.org/

- **Alna's Juniper Hill School Reopening**  
  https://lcnme.com/school/alnas-juniper-hill-school-reopens-board-addresses-closure/

- **MMCFC Falcon Auburn**  
  https://www.niche.com/k12/mmcfc-falcon-auburn-me/

- **Margaret Murphy Center Potential Cuts**  
  https://www.wmtw.com/article/families-distressed-about-potential-margaret-murphy-cuts/2012827

- **Toddle Inn Child Care Reviews**  
  https://www.indeed.com/cmp/Toddle-Inn-Child-Care/reviews?fcountry=US&floc=Auburn%2C+ME

- **Maine Legislature Testimony**  
  https://legislature.maine.gov/legis/bills/getTestimonyDoc.asp?id=180932

- **Toddle Inn**  
  https://toddleinn.com/

---

## Data Limitations

### Data Quality Challenges

**Inconsistent Reporting & Incomplete Records**

We encountered significant challenges with data quality and completeness during this project. Maine's school closure data is fragmented across multiple sources with inconsistent formatting, missing closure dates, and incomplete facility information. We have submitted data requests to the Maine Department of Education and continue to advocate for better public data infrastructure.

### Known Gaps and Constraints

**Closure Timing:**
- Some closure dates are approximate or based on last available enrollment data
- Private school closures are significantly under-reported compared to public schools
- Exact closure dates are often unavailable in public records

**Building Condition:**
- Facility condition assessments are not comprehensively available for most schools
- Deferred maintenance data is limited to publicly reported information
- Inspection reports are often not publicly accessible without FOAA requests

**Financial Data:**
- Individual school district budgets and bond vote results require extensive manual research
- State funding application outcomes are not always publicly accessible in real-time
- Historical funding decisions are difficult to track systematically

**Predictive Limitations:**
While our pattern analysis identifies key risk factors, it cannot account for:
- Sudden policy changes or emergency funding
- Unexpected funding sources (federal grants, private donations)
- Community-specific factors not captured in quantitative data
- Successful grassroots efforts to prevent closures
- Political will and local decision-making dynamics

---

## Citation

When referencing this work, please cite as:

[Rachel Schoenberg, Cody Snow, and Hardik Bisnoi]. (2025). *Maine School Closures: A Predictable Crisis*. Data visualization project for Maine Redevelopment Land Bank Authority. 

