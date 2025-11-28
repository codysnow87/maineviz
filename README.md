# MRLBA Property Analysis & Visualization
 
## CS7250 Information Visualization: Theory & Applications
 
**Project Title:** *A-Maine-Zing Visualizations*
 
**Status:** Collaborative project between Analytics Capstone and Data Visualization teams for interactive mapping
---
## Project Overview
 
### Stakeholders
- **Jen Litteral** - Maine Redevelopment Land Bank Authority
- **Dan Black** - Maine Redevelopment Land Bank Authority
 
### Problem Statement
 
The Maine Redevelopment Land Bank Authority (MRLBA) is statutorily directed to assist municipalities with vacant, abandoned, environmentally hazardous, and functionally obsolete properties. However, there is currently **no centralized database** of these properties across the state.
 
This project aims to create a centralized data and analytics tool with interactive visualizations to help MRLBA and partner organizations effectively identify, track, and revitalize properties across Maine.
 
### Impact
 
By visualizing property types, geographic locations, and ownership information, this tool will enable:
- More effective identification of redevelopment opportunities
- Equitable action to return properties to productive use
- Data-driven decision making for community revitalization
 
## Project Goals
 
### Minimum Viable Product (MVP)
 
Create an interactive visualization system for vacant, abandoned, environmentally hazardous, and functionally obsolete properties with the following priority data layers:
 
#### 1. Brownfield Data
- Active vs. non-active status
- Sites vs. buildings classification
- Historic vs. current designations
 
#### 2. School Data
- Open vs. closed status
- Schools at risk of closure
 
#### 3. Utility & Occupancy Data
- Utility shut-off records
- USPS returned mail addresses
- Public ownership status
- Commercial building identification
- Seasonal closure patterns
 
#### 4. Parcel Data
- **Priority parcels:** Closed schools, EPA issues, vacant/foreclosed properties
- Geographic coverage limited to digitized counties
- Current use classification
- Year built
- USDA foreclosed homes (pending MRLBA data)
- Ownership types: Public, bank-owned, institutional investors
 
> **Note:** Not all Maine counties have digitized parcel maps. Collaboration with Data for Good is underway for a separate project to digitize PDF parcel data from additional counties.
 
### Expected Final Deliverable
 
**MVP functionality PLUS:**
- Real-time data feeds from multiple public and private datasets
- Comprehensive property profiles including:
  - Tax foreclosure status and year
  - Contamination status, type, and Brownfield funding history
  - Vacancy status and duration
 
### Stretch Goals
 
An optimal tool that provides metrics to:
 
1. **Identify** all vacant, abandoned, environmentally hazardous, and functionally obsolete properties across Maine
2. **Manage** redevelopment opportunities through visual analytics
3. **Track** redevelopment outcomes for reporting purposes
4. **Enable** data-based feedback loops for program design and continuous improvement
 
## Data Sources
 
**Primary Data Provider:** [Tolemi](https://www.tolemi.com/)
 
Additional data sources include:
- EPA Brownfield databases
- State and county parcel records
- School district records
- Utility companies
- USPS
- USDA foreclosure data
- Local municipal records
 
## Technical Approach
 
## How To Run
- Clone Repository:
    git clone https://github.com/nudataviz/project-fall25-RachelSchoenberg.git
    cd MaineViz
- Install Observable Framework:
    npm install
-  Start The Framework:
    npm run dev

## Team
 
| Name | Role |
|------|------|
| Rachel Schoenberg | **Team Lead** |
| Cody Snow| Member |
| Hardik Bishnoi | Member |
 
 
## Timeline
 
10/10/2025 Proposal Due
10/16/2025 EDA Due
10/24/2025 Project Status Update
10/31/2025 MVP Presentations
11/7/2025 Peer Review Due
11/14/2025 Peer Review Response Due
11/21/2025 Project Status Update
12/5/2025 Project Presentations (Repo Due)
 
## Repository Structure
```
/
├── MaineViz/src/eda.md # File explaining initial Exploratory Data Analysis
├── data/               # Data files and preprocessing scripts
├── visualizations/     # Visualization implementations
├── docs/              # Project documentation
├── notebooks/         # Analysis notebooks
└── README.md          # This file
```
---
## Acknowledgments
 
- **Maine Redevelopment Land Bank Authority** for project sponsorship and domain expertise
- **CS7250 Course Staff** for guidance and support
- **Data for Good** for collaboration on parcel data digitization
 
 
**Course:** CS7250 Information Visualization: Theory & Applications  
**Institution:** The Roux Institute  
**Semester:** Fall 2025
