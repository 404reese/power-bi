# Sugarcane Irrigation Advisory Dashboard (Power BI Project)

Use case KJS-AGR-01: AI-based irrigation advisory for sugarcane (KIAAR / GBL). The data covers 1,000 geofenced sugarcane plots in Mandya district, Karnataka, across 6 taluks and 10 villages.

## How to open it

1. You can unzip this folder anywhere. The report reads `Data\IrrigationAdvisoryDataset.csv` when the folder is at `C:\Users\riddh\Documents\Irrigation-Advisory-Dashboard\`. Anywhere else, it automatically uses a copy of the same CSV that's stored inside the model, so it still loads with no setup.
2. Double-click **`Sugarcane Irrigation Advisory.pbip`**, then click **Refresh**.
3. To get a single file to submit, use **File > Save as** and pick the `.pbix` type.

## Pages

| Page | What it shows |
|---|---|
| 1. Farm Overview | KPIs, a village map, the advisory mix, stress levels and a taluk breakdown |
| 2. Soil and Crop Health | NDVI by village, soil moisture vs NDVI for each plot, a taluk/village indicator matrix, crop vigour classes |
| 3. Weather and Water Balance | Rainfall, temperature, humidity, VPD and sugarcane water use (ETc) |
| 4. Irrigation Advisory | A depletion gauge, pump hours, energy, yield-loss risk, the auto advisory text, a plot-wise schedule and a plot map |
| 5. What-if and AI Visuals | Sliders for forecast rain, pump flow and irrigation efficiency, a decomposition tree and Q&A |
| Farm Details (drill-through) | Right-click any plot in the page 4 table and choose Drill through > Farm Details |
| Village Tooltip (hidden) | Hover over the NDVI bars on page 2 |

Row-level security: go to Modeling > View as and pick `Malavalli Field Supervisor` or `Krishnarajpet Field Supervisor`.

## Data cleaning (Power Query, query `Farms`)

1. The CSV is imported with proper quote handling. This matters because the `.geo` column contains GeoJSON with commas inside it.
2. Farm IDs and place names are trimmed, blank IDs are removed, and duplicate Farm_IDs are removed.
3. Numbers are converted using a fixed culture, so decimals read correctly on any PC.
4. Range checks turn impossible sensor values into null: NDVI outside -1 to 1, soil moisture outside 0 to 0.6, pH outside 3 to 10, RH outside 0 to 100, LAI outside 0 to 10.
5. **6 plots have missing NDVI** (cloud-masked pixels). These are filled with their village's median NDVI and flagged in `NDVI_Imputed`.
6. Each plot's centre point (latitude/longitude) is calculated from its GeoJSON polygon.
7. Two columns are dropped: `Sampling_Method` (the same value on every row) and the raw geometry.

What I noticed in the data, which is worth mentioning in your report:
- Every plot has the same area (0.7355 ha), so the geofences are fixed-size buffers, not true field boundaries.
- Rainfall, temperature and humidity come from a coarse weather grid, so they only have 14 to 38 distinct values.
- Soil moisture is satellite-derived, which is why it varies so little between plots.

## Advisory logic (calculated columns, FAO-56 water balance)

| Item | Value or formula |
|---|---|
| Field capacity / wilting point | 0.30 / 0.14 m³/m³ (assumed for Mandya red sandy-clay loam) |
| Root zone | 600 mm, so total available water (TAW) is 96 mm |
| Irrigation trigger | Irrigate at 50% depletion (48 mm deficit), the standard sugarcane recommendation |
| Root Zone Deficit | (0.30 − soil moisture) × 600 mm |
| Crop water use | ET0 by Hargreaves × Kc 1.25 (sugarcane, grand growth stage), about 5.6 mm/day |
| Days to Next Irrigation | (48 − deficit) ÷ ETc |
| Advisory Category | Irrigate Today / Irrigate in 1-3 Days / Irrigate in 4-7 Days / No Irrigation Needed |
| Water Stress Score (0-100) | 60% soil-water depletion + 25% low NDVI + 15% atmospheric demand (VPD) |
| Irrigation volume | deficit ÷ 60% furrow efficiency × area × 10 (m³) |
| Pump hours / power slots | volume ÷ 30 m³/h pump; slots are the 7-hour daily 3-phase power windows needed |
| Yield loss risk | FAO-33 Ky = 1.2, applied to the stress the crop would suffer if irrigation is delayed by 3 days |
| Water saved | compared with the usual fixed 100 mm flood irrigation on every plot |
| Fertigation advice | rules based on NDVI and soil pH |

All of these are assumptions you can change. They're written as plain numbers in the calculated columns of the `Farms` table.

## Check your numbers

After a refresh, with no filters applied, you should see:

| Measure | Expected |
|---|---|
| Plots monitored | 1,000 |
| Plots to irrigate today | 614 |
| Water required today | about 368,700 m³ |
| Avg water stress score | 56.8 |
| High-stress plots | 439 |
| Water saved vs farmer practice | about 49.9% |

## Troubleshooting

- **You edited the CSV but the report doesn't change:** the folder isn't at the default path, so the built-in copy is being used. Go to Transform data > Manage parameters > `DataFolder`, enter the full path to this `Data` folder ending with `\`, then click Refresh. (Power BI has no relative-path option, which is why this parameter exists.)
- **The map is blank:** turn on File > Options > Security > "Use Map and Filled Map visuals". The plot map on page 4 is a scatter chart, so it always works.
- **A visual says "Select or drag fields":** send me a screenshot and I'll fix it.
