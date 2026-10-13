# India Heatwave Dashboard (Power BI Project)

Power BI project built from the four IMD city files (Delhi, Mumbai, Kolkata, Bangalore; daily data, 1 Jan 1951 to 22 Jun 2024).

## How to open it

1. Keep this folder at `C:\Users\riddh\Documents\India-Heatwave-Dashboard\`. If you move it, update the path (see Troubleshooting).
2. Double-click **`India Heatwave Dashboard.pbip`**. This opens it in Power BI Desktop.
3. Click **Refresh** on the Home ribbon. The data loads from the `Data` folder, which takes about 30 to 60 seconds.
4. To get a single file to submit, use **File > Save as** and pick the `.pbix` type.

If Power BI says the report format isn't supported, turn on these two options under **File > Options and settings > Options > Preview features**, then restart Power BI Desktop:
- Power BI Project (.pbip) save option
- Store reports using enhanced metadata format (PBIR)

## What's inside

| Assignment phase | Where it is |
|---|---|
| Phase 2: Power Query / ETL | Transform data > `fnCleanCity` (cleans one file) and `WeatherData` (combines the files and adds the daily normals) |
| Phase 2: calculated columns | `City[Region]`, `City[Terrain]`, `WeatherData[Heatwave Status]`, `WeatherData[Alert Level]`, `WeatherData[Departure]`, `Date[Season]` |
| Phase 3: 4 pages | 1. National Overview, 2. Regional Analysis, 3. Trends and Seasons, 4. Early Warning |
| Phase 4: DAX measures | The `WeatherData` table, in display folders 1 to 6 (33 measures) |
| Phase 5: advanced features | Page 5 and the hidden pages (see below) |

### Data cleaning (Power Query)

The raw files had these real problems. Each one is handled in `fnCleanCity`:

- **Mixed date formats.** Most rows are `dd-MM-yyyy`, but the last rows of the Delhi, Mumbai and Kolkata files are Excel serial numbers (for example `45463` = 19-06-2024). Both formats are converted to real dates.
- **Transmission dropouts.** Placeholders like `---`, `----`, `-----` and blank cells become null.
- **Trace rain.** `Tr` means less than 0.1 mm of rain. It's stored as 0, and the `RainTrace` column records that it was trace.
- **Sensor anomalies.** Values that are physically impossible are removed: Tmax outside 0 to 50 °C, Tmin outside -5 to 40 °C, Tmin at or above Tmax, or more than 500 mm of rain in a day. This catches Bangalore's Tmin of 73.8 °C and the 1014.5 mm (Kolkata) and 1011.7 mm (Mumbai) rain readings, all on 01-12-2023.
- **Missing days.** January 2024 is missing entirely for three cities. The calendar is completed so these days show up as "Missing" instead of disappearing.
- **Short gaps.** A gap of 3 days or less is filled with the last valid reading and flagged "Imputed". Longer gaps stay empty.
- **Data quality flag.** Every row is tagged Original, Imputed, Missing or Outlier Removed. The City Details page shows the breakdown.
- **Mumbai rainfall** is only present from 2021 onwards in the source file, so rain visuals are sparse for Mumbai.

### Heatwave logic (IMD criteria)

The simple thresholds in the assignment brief have been upgraded to the actual IMD rules:

- Plains (Delhi, Kolkata, Bangalore): Tmax of at least 40 °C **and** a departure from normal of at least 4.5 °C counts as a Heatwave. A departure above 6.4 °C counts as Severe. Any day at 45 °C or more is a Heatwave, and 47 °C or more is Severe.
- Coastal (Mumbai): the same rule, but with a 37 °C threshold. Hilly areas would use 30 °C.
- "Normal" means the 1991-2020 average Tmax for that city and calendar day, calculated in Power Query.
- Alert colours: Green = normal, Yellow = above the threshold but not a heatwave, Orange = Heatwave, Red = Severe.

The Region formula from the brief has also been fixed. As written, it labelled Mumbai "South Plains" and Kolkata "Other" because the conditions were checked in the wrong order.

### Advanced features

| Feature | Where |
|---|---|
| Drill-down | Page 2 bar chart: Region > City (use the drill arrows on the visual) |
| Drill-through | On page 2 or 4, right-click a city and choose **Drill through > City Details** |
| Custom tooltip page | Hover over the page 2 bar chart |
| What-if parameter | Page 5 slider, `Temp Increase` from 0 to 5 °C |
| Decomposition tree | Page 5 |
| Q&A visual | Page 5. Try "heatwave days by city" |
| Forecast and trend | Page 3 line chart (5-year forecast, 95% band) |
| Row-level security | Modeling > View as > `North Region Analyst` or `Coastal Region Analyst` |
| Bookmarks | **Do this yourself (2 minutes).** Steps below |

**Adding bookmarks:** Go to page 2 and open View > Bookmarks. Hide the donut (View > Selection pane) and click **Add**, then rename the bookmark "Temperature View". Show the donut again, hide the heatmap, and click **Add** again, naming it "Alert View". Finally, add two buttons (Insert > Buttons > Blank) and set each one's Action to Bookmark.

## Check your numbers

After a refresh, with no filters applied, you should see:

| Measure | Expected |
|---|---|
| Heatwave Days (all cities) | 413 |
| Severe Heatwave Days | 40 |
| Avg Max Temp | 31.3 °C |
| Delhi heatwave days | 362 |
| Delhi record max | 47.5 °C |
| Active Alerts (last 30 days) | 13 (all in Delhi, June 2024) |

## Troubleshooting

- **"Could not find a part of the path" on refresh:** the folder was moved. Go to Transform data > Manage parameters > `DataFolder` and enter the new path to the `Data` folder, ending with `\`.
- **Maps show a warning:** turn on File > Options > Security > "Use Map and Filled Map visuals". If your organisation blocks Azure Maps, the maps stay blank but everything else still works.
- **A visual shows "Something's wrong with one or more fields":** click the visual and re-drag the field listed in the error from the Data pane.
