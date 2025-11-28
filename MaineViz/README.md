# MaineViz

Data files in shared folder in OneDrive: https://northeastern-my.sharepoint.com/shared?id=%2Fpersonal%2Fd%5Fkoloski%5Fnortheastern%5Fedu%2FDocuments%2FMRLBA%2DTolemi%2DRoux%2DXfer&listurl=%2Fpersonal%2Fd%5Fkoloski%5Fnortheastern%5Fedu%2FDocuments

Folder with relevant file: MRLBA-Tolemi-Roux-Xfer/asset_cejst_additionalchars_demographics_supplemental_tables.zip

MRLBA-Tolemi-Roux-Xfer/asset_master_table.zip/asset_master_table/asset.csv



Folder is from Dan Koloski, called MRLBA-Tolemi-Roux-Xfer

[Instructions](https://discuss.python.org/t/how-to-convert-a-csv-file-to-parquet-without-rle-dictionary-encoding-error-message/18786) to create parquet files in python:
```python
import pandas as pd
df = pd.read_csv("me_maine_redevelopment_land_bank_epa_brownfield_sites_86314_base.csv") 
df.to_parquet("brownfield.parquet")

df = pd.read_csv("asset.csv") 
df.to_parquet("asset.parquet")
```

This is an [Observable Framework](https://observablehq.com/framework/) app. To install the required dependencies, run:

```
npm install
```

Then, to start the local preview server, run:

```
npm run dev
```

Then visit <http://localhost:3000> to preview your app.

For more, see <https://observablehq.com/framework/getting-started>.

## Project structure

A typical Framework project looks like this:

```ini
.
├─ src
│  ├─ components
│  │  └─ timeline.js           # an importable module
│  ├─ data
│  │  ├─ launches.csv.js       # a data loader
│  │  └─ events.json           # a static data file
│  ├─ example-dashboard.md     # a page
│  ├─ example-report.md        # another page
│  └─ index.md                 # the home page
├─ .gitignore
├─ observablehq.config.js      # the app config file
├─ package.json
└─ README.md
```

**`src`** - This is the “source root” — where your source files live. Pages go here. Each page is a Markdown file. Observable Framework uses [file-based routing](https://observablehq.com/framework/project-structure#routing), which means that the name of the file controls where the page is served. You can create as many pages as you like. Use folders to organize your pages.

**`src/index.md`** - This is the home page for your app. You can have as many additional pages as you’d like, but you should always have a home page, too.

**`src/data`** - You can put [data loaders](https://observablehq.com/framework/data-loaders) or static data files anywhere in your source root, but we recommend putting them here.

**`src/components`** - You can put shared [JavaScript modules](https://observablehq.com/framework/imports) anywhere in your source root, but we recommend putting them here. This helps you pull code out of Markdown files and into JavaScript modules, making it easier to reuse code across pages, write tests and run linters, and even share code with vanilla web applications.

**`observablehq.config.js`** - This is the [app configuration](https://observablehq.com/framework/config) file, such as the pages and sections in the sidebar navigation, and the app’s title.

## Command reference

| Command           | Description                                              |
| ----------------- | -------------------------------------------------------- |
| `npm install`            | Install or reinstall dependencies                        |
| `npm run dev`        | Start local preview server                               |
| `npm run build`      | Build your static site, generating `./dist`              |
| `npm run deploy`     | Deploy your app to Observable                            |
| `npm run clean`      | Clear the local data loader cache                        |
| `npm run observable` | Run commands like `observable help`                      |
