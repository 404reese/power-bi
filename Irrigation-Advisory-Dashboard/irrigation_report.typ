// Sugarcane Irrigation Advisory DSS: BI report (Typst)
// HOW TO ADD SCREENSHOTS: save each PNG next to this file using the file names
// listed in the `shots` dictionary below (1.png to 6.png), keep `use-shots` true and recompile.
// Set `use-shots` to false to compile with grey placeholder boxes instead.

#let use-shots = true
#let shots = (
  overview: "1.png",
  soil: "2.png",
  weather: "3.png",
  advisory: "4.png",
  whatif: "5.png",
  farm: "6.png",
)


#set document(title: "Case Study: Sugarcane Irrigation Advisory Dashboard and Decision Support System")
#set page(paper: "us-letter", margin: (x: 1in, y: 0.9in), numbering: "1", number-align: center)
#set text(font: ("Times New Roman", "Liberation Serif"), size: 11pt, lang: "en")
#set par(justify: true, leading: 0.62em, spacing: 0.85em)
#set list(indent: 0.8em, body-indent: 0.6em, marker: [•])

#show heading.where(level: 1): it => block(above: 1.2em, below: 0.6em, text(size: 11.5pt, weight: "bold", it.body))
#show figure.caption: it => align(center, text(size: 10.5pt, weight: "bold", it.body))
#show figure: set block(breakable: false, above: 1em, below: 1em)

#let shot(key, alt) = {
  if use-shots {
    image(shots.at(key), width: 100%)
  } else {
    rect(width: 100%, height: 2.6in, stroke: (paint: luma(150), dash: "dashed"), fill: luma(245), radius: 3pt,
      align(center + horizon, text(fill: luma(100), size: 10pt)[Screenshot placeholder: #alt \ (#shots.at(key))]))
  }
}
#let fig(key, alt, cap) = figure(shot(key, alt), caption: cap, supplement: none, numbering: none)
#let lab(t) = block(above: 0.7em, below: 0.3em, sticky: true, text(weight: "bold", t))

#let tbl(..a) = {
  set text(size: 10pt)
  table(stroke: 0.5pt + luma(120), inset: 5pt, fill: (x, y) => if y == 0 { luma(230) }, ..a)
}

// ---------------- Title ----------------
#align(center)[
  #text(size: 16pt, weight: "bold")[Case Study: Sugarcane Irrigation Advisory Dashboard \ and Decision Support System (DSS)] \
  #v(0.2em)
  #text(size: 10.5pt)[Power BI project for Use Case KJS-AGR-01 (KIAAR and Godavari Biorefineries): 1,000 geofenced sugarcane plots, Mandya district, Karnataka]
]
#v(0.6em)

= 1. Problem Statement & DSS Context

Sugarcane is one of the most water-intensive field crops, yet most irrigation in the KIAAR and Godavari Biorefineries (GBL) catchment is still scheduled from the farmer's experience rather than from the actual moisture in the root zone. The result is a familiar pair of errors: over-irrigation, which wastes water, pumping electricity and nutrients, and delayed irrigation, which stresses the crop and costs yield. With 18,000 to 25,000 farmers spread over thousands of mapped plots, field staff also cannot inspect every plot in person. The objective of this Business Intelligence (BI) initiative is to build a Decision Support System (DSS) that combines satellite-derived soil moisture and vegetation indices, weather and soil data for every geofenced plot, computes how much of the crop's available water has already been used, and converts that into a plot-specific advisory: irrigate today, irrigate in 1 to 3 days, irrigate in 4 to 7 days, or no irrigation needed.

The DSS turns raw readings into decisions in three steps. A reading (plot `MM-MD-0773` in Ankegowdanadoddi, Maddur: soil moisture 0.219 m³/m³) is compared with the soil's field capacity (0.30 m³/m³) over a 600 mm root zone to produce intelligence (a 48.3 mm root-zone deficit, or 50.3% of the available water already used), which the advisory logic converts into an operational decision (irrigate today with 592 m³, about 19.7 pump hours spread over three 7-hour power windows, plus a nitrogen top-up because the plot's NDVI is only 0.31).

= 2. Data Preparation & ETL Architecture

The data foundation is a single Google Earth Engine extract with one row per geofenced sugarcane plot: 1,000 plots in 6 taluks and 10 villages of Mandya district. Each row carries the plot ID, location (district, taluk, village), plot area, satellite soil moisture, NDVI, LAI, soil pH, organic carbon, seasonal rainfall, air temperature, relative humidity and the plot boundary as a GeoJSON polygon. All cleaning is done in Power Query in one documented query (`Farms`).

- *Data Ingestion:* the CSV is read with full quote handling, because the `.geo` column holds GeoJSON with commas and doubled quotes inside it. A `DataFolder` parameter points to the `Data` folder, and a compressed copy of the same CSV is stored in the model so that the report also refreshes on a PC where that folder does not exist.
- *Key and Text Hygiene:* plot IDs are trimmed and upper-cased, blank IDs are removed and duplicate plot IDs are dropped (none were found). Taluk and village names are trimmed.
- *Type Safety:* every numeric field is converted with a fixed culture so that decimals are read correctly on any regional setting.
- *Sensor Range Checks:* physically impossible values become null (NDVI outside -1 to 1, soil moisture outside 0 to 0.6 m³/m³, pH outside 3 to 10, humidity outside 0 to 100%, LAI outside 0 to 10). No values failed these checks in this extract.
- *Missing NDVI and Imputation:* 6 plots have no NDVI, the typical result of cloud-masked satellite pixels. They are filled with the median NDVI of their own village and flagged in an `NDVI_Imputed` column, so the imputation stays visible.
- *Feature Engineering (Geospatial):* the plot centroid (latitude and longitude) is calculated from each GeoJSON polygon, and a village location string is built for map geocoding. `Sampling_Method` is dropped because it holds the same value on every row.

#figure(
  tbl(columns: (1.6fr, 0.8fr, 3.4fr), align: (left, right, left),
    [Data quality check], [Result], [Action / meaning],
    [Plots (rows)], [1,000], [One row per geofenced plot, all unique `Farm_ID`],
    [Duplicate plot IDs], [0], [Duplicates would be removed],
    [Missing NDVI], [6 (0.6%)], [Filled with village median, flagged `NDVI_Imputed`],
    [Out-of-range sensor values], [0], [Would be set to null],
    [Constant columns], [3], [District, `Sampling_Method` and plot area have one value each],
    [Organic carbon at default value], [885 (88.5%)], [Value of exactly 10 suggests a modelled default, used with caution],
  ),
  caption: [Table 2.1: Data quality profile after cleaning],
  supplement: none, numbering: none,
)

The semantic model is a single plot-level fact table (`Farms`) with a District, Taluk, Village and Plot hierarchy, plus three disconnected what-if parameter tables (forecast rain, pump flow and irrigation efficiency) that drive the scenario page. All agronomic logic is built as DAX calculated columns so that every plot carries its own deficit, schedule, stress score and advisory.

= 3. Predictive Modeling & Classification in BI

The DSS uses a transparent, rule-based soil water balance that follows FAO-56 crop water requirement methods. This is deliberately explainable: an agronomist can check every number on a calculator, which is a requirement for farmer trust and for the human-in-the-loop governance set out in the use case.

#figure(
  tbl(columns: (1.5fr, 3.5fr), align: (left, left),
    [Model element], [Formula / assumption as implemented],
    [Soil water limits], [Field capacity 0.30 m³/m³, wilting point 0.14 m³/m³ (Mandya red sandy-clay loam, assumed)],
    [Root zone and available water], [600 mm root zone, so total available water (TAW) = 96 mm],
    [Irrigation trigger], [Irrigate at 50% depletion of available water (48 mm deficit), the standard sugarcane recommendation],
    [Root Zone Deficit], [(0.30 − soil moisture) × 600 mm],
    [Crop water use (ETc)], [Hargreaves ET0 (Ra 15 mm/day, diurnal range 10°C assumed) × Kc 1.25 for grand growth, about 5.6 mm/day],
    [Days to Next Irrigation], [(48 mm − deficit) ÷ ETc, floored at zero],
    [Irrigation dose], [Deficit ÷ 60% furrow efficiency × plot area × 10 = m³; pump hours at 30 m³/h; 5 HP pump (3.73 kW)],
    [Yield loss risk], [FAO-33 yield response factor Ky = 1.2 applied to the water stress after a 3-day delay],
    [Water Stress Score (0-100)], [60% soil-water depletion + 25% low NDVI + 15% vapour pressure deficit (VPD)],
  ),
  caption: [Table 3.1: Soil water balance and stress model],
  supplement: none, numbering: none,
)

#figure(
  tbl(columns: (1.5fr, 0.8fr, 2.8fr), align: (left, right, left),
    [Advisory tier], [Plots], [Rule as implemented in the model],
    [Irrigate Today], [614], [Root-zone deficit has reached the 48 mm (50%) trigger],
    [Irrigate in 1-3 Days], [287], [Trigger will be reached within 3 days at the current ETc],
    [Irrigate in 4-7 Days], [99], [Trigger will be reached in 4 to 7 days],
    [No Irrigation Needed], [0], [More than 7 days of readily available water left],
  ),
  caption: [Table 3.2: Advisory tiers and plot counts],
  supplement: none, numbering: none,
)

The stress score adds two signals that soil moisture alone cannot show: crop vigour (NDVI) and atmospheric demand (VPD). It bands plots as High (score of 60 or more, 439 plots), Moderate (40 to 60, 462 plots) and Low (below 40, 99 plots), with an average of 56.8. The schedule table on page 4 sorts plots by this score so that the most stressed plots are irrigated first when pumps or power are limited.

The cost of error is asymmetric. An unnecessary irrigation costs water, electricity and some leached nitrogen, all of which are recoverable. A missed or late irrigation during the grand growth stage causes stress that cannot be undone: the model estimates a 44% relative yield reduction over the stress period for a due plot that waits another 3 days. The trigger is therefore set at the conservative 50% depletion level rather than the 65% that FAO-56 allows for sugarcane, which favours crop safety over maximum water saving.

= 4. Reporting, Authoring & Visual Analytics

The report has five main pages, a drill-through page and a hidden tooltip page. A taluk slicer on each main page lets field supervisors move between the district view and their own taluk, and one colour code is used throughout: red for Irrigate Today, orange for 1 to 3 days, yellow for 4 to 7 days and green for no irrigation needed.

#fig("overview", "Page 1, Farm Overview", [Figure 4.1: Farm Overview, Irrigation Demand and Stress Mix])

#lab[Description:]
Page 1 combines five KPI cards (plots monitored, plots to irrigate today, water required today, average water stress score and water saved compared with farmer practice), a village bubble map sized by plots to irrigate today, donut charts of plots by advisory tier and by stress level, and a stacked bar chart of the advisory mix by taluk.

#lab[BI Decision Analysis:]
- Of 1,000 plots (735.5 ha), 614 (61.4%) need irrigation today, 287 (28.7%) within 1 to 3 days and 99 (9.9%) within 4 to 7 days. No plot can wait more than a week, which fits the high water demand of sugarcane at grand growth.
- Today's demand is 368,680 m³. Under the usual practice of a fixed 100 mm flood on every plot, the same area would receive 735,507 m³, so targeting only the plots that are due, with only the water they need, saves 49.9%.
- Demand is concentrated geographically. Every plot in Pandavpura (205) and Mandya taluk (189) is due today, while none in Shrirangapattana (93) is. Malavalli has only 39 of 204 due, and Krishnarajpet is split village by village (all 108 in Chowda Ghatta due, none of 99 in Laxmipura).
- 439 plots (43.9%) are in the High stress band and only 99 (9.9%) are Low.
- *Operational Impact:* serves as a Macro Resource Allocation view. Cane supervisors and pump-operator teams should be sent to Pandavpura and Mandya taluk first, while Shrirangapattana can be scheduled for the following days.

#fig("soil", "Page 2, Soil and Crop Health", [Figure 4.2: Soil Moisture, Crop Vigour and Soil Indicators])

#lab[Description:]
Page 2 holds a column chart of average NDVI by village, a scatter plot of soil moisture against NDVI for every plot (coloured by stress level), a taluk-to-village matrix of soil and crop indicators (plots, soil moisture, depletion, NDVI, LAI, pH, organic carbon and stress, with depletion and stress shaded), and a donut of plots by crop vigour class. Hovering over a village bar opens a custom tooltip page with plots, plots to irrigate, soil moisture and stress score.

#lab[BI Decision Analysis:]
- Average NDVI ranges from 0.549 in Bheemanahalli and 0.550 in Hadya (weakest canopies) to 0.612 in Chowda Ghatta and 0.621 in Hosur (strongest). 421 plots show healthy vigour (NDVI of 0.6 or more), 544 moderate and 35 poor (below 0.4), with the most poor-vigour plots in Ankegowdanadoddi (8) and Hadya (6).
- Soil moisture and NDVI are almost uncorrelated across plots (r = −0.03). Canopy greenness reacts to water stress with a delay, so NDVI cannot replace a soil moisture reading for scheduling. It is used instead as an additional stress signal.
- Laxmipura (Krishnarajpet) stands out with the wettest soil (0.253 m³/m³, 29.5% depletion) and the lowest stress score (26.8). The other nine villages sit between 46.7% and 51.5% depletion, right at the irrigation trigger.
- Soils are slightly acidic on 704 plots (pH below 6.5) and neutral on 296, with no alkaline plots. 225 plots have pH below 6.2; the 195 of these without low vigour are advised to lime in the fertigation advice (low-vigour plots get the nitrogen advice first).
- *Operational Impact:* identifies villages where poor vigour and high depletion occur together (Ankegowdanadoddi, Hadya, Bheemanahalli) for a combined irrigation and nutrient visit.

#fig("weather", "Page 3, Weather and Water Balance", [Figure 4.3: Weather Drivers and Crop Water Balance])

#lab[Description:]
Page 3 shows five weather KPI cards (seasonal rainfall, temperature, humidity, vapour pressure deficit and sugarcane water use), a bar chart of average rainfall by taluk, a scatter of rainfall against soil moisture by village (bubble size equals plots), a column chart of average depletion by rainfall zone, and a bar chart of crop water use (ETc) by village.

#lab[BI Decision Analysis:]
- Seasonal rainfall averages 630 mm but ranges from 498 mm to 711 mm. Krishnarajpet is the wettest taluk (708 mm) and Malavalli the driest (509 mm).
- The atmosphere is mild and humid (temperature 22.2 to 24.2°C, humidity 78.9%, VPD 0.61 kPa), so crop water use is steady at about 5.6 mm/day. It is highest in Ankegowdanadoddi (5.72 mm/day, the warmest and driest air) and lowest in Chowda Ghatta (5.45 mm/day).
- Seasonal rainfall explains little of today's soil moisture (r = 0.22). High-rainfall plots average 47.3% depletion, medium 50.8% and low 48.4%. Season totals do not tell a farmer when to irrigate; the current moisture and the short-range rain forecast do.
- *Operational Impact:* supports the rainfall-adjusted advisory in the use case. Scheduling must use the near-term forecast (page 5), not seasonal averages.

#fig("advisory", "Page 4, Irrigation Advisory", [Figure 4.4: Irrigation Advisory and Plot Schedule Console])

#lab[Description:]
Page 4 is the operational console. It shows a gauge of average depletion against the 50% trigger, cards for pump hours, electricity and yield loss risk, an auto-generated advisory text for the current selection, water required today by village, a plot-wise schedule table (soil moisture, depletion, stress score, days to irrigation, pump hours, power slots and colour-coded advisory) sorted by stress, and a plot map of centroids coloured by advisory.

#lab[BI Decision Analysis:]
- Average depletion is 48.2% against the 50% trigger, so the district as a whole sits just below the line while 614 individual plots are above it.
- Today's plan needs 12,289 pump hours and 45,839 kWh. A typical plot needs a gross dose of 81 mm (592 m³), which is about 19.9 hours at 30 m³/h, or three 7-hour power windows (901 plots need 3 windows, 99 need 2). Each irrigation cycle therefore takes three days of rural 3-phase supply, which is why the schedule must be started early.
- The largest village demands today are Chowda Ghatta (65,044 m³), Talasasana (64,134 m³), Kachenahalli (60,007 m³), Hadya (56,708 m³) and Chikkathammanahalli (56,111 m³).
- If due plots wait 3 more days, the average yield loss risk is 44.4% for the stress period (38.5% across all plots).
- The advisory text is generated by a DAX rule. For a single plot it reads like the use case example: "Irrigate today. Run the pump for about 19.7 hours (592 m³), split over 3 power slot(s), starting early morning", followed by the fertigation advice.
- *Operational Impact:* gives cane supervisors a ranked work list and gives the factory a daily water and electricity estimate for pump scheduling.

#fig("whatif", "Page 5, What-if and AI Visuals", [Figure 4.5: Scenario Planner and AI Visuals])

#lab[Description:]
Page 5 contains three what-if sliders: forecast rain for the next 3 days (0 to 50 mm, 80% treated as effective), pump flow (30 to 80 m³/h) and irrigation efficiency (60% furrow to 95% drip). It shows the plots to irrigate, water needed and pump hours under the scenario, a column chart of today's water against the scenario water by taluk, a decomposition tree of today's water by taluk, village, stress level, NDVI class, rainfall zone and pH class, and a natural-language Q&A visual.

#lab[BI Decision Analysis:]
#figure(
  tbl(columns: (2fr, 1fr, 1.2fr, 1fr, 1fr), align: (left, right, right, right, right),
    [Scenario], [Plots due], [Water (m³)], [Pump hours], [Saved],
    [Baseline: no rain, furrow 60%, 30 m³/h], [614], [368,680], [12,289], [49.9%],
    [Switch to drip (90% efficiency)], [614], [245,787], [8,193], [66.6%],
    [Larger pump (50 m³/h), furrow], [614], [368,680], [7,374], [49.9%],
    [5 mm rain forecast (4 mm effective)], [0], [0], [0], [100%],
  ),
  caption: [Table 4.5: What-if scenarios for today's irrigation],
  supplement: none, numbering: none,
)
- Moving from furrow to drip irrigation cuts today's water by a third (from 368,680 to 245,787 m³) and raises the saving against farmer practice from 49.9% to 66.6%.
- A larger pump does not save water, but it cuts pump hours from 12,289 to 7,374, which matters when power is only available for 7 hours a day.
- The forecast is the most powerful lever. 793 of 1,000 plots are within 2 mm of the trigger, so even 5 mm of forecast rain moves every plot below it, and the advice becomes "rain is expected, irrigation is not required today". This shows why the use case calls for rainfall-adjusted recommendations, and also how sensitive the advisory is to forecast accuracy.
- The decomposition tree shows that Pandavpura (124,141 m³, 33.7%) and Mandya taluk (112,819 m³, 30.6%) together account for almost two-thirds of today's water.
- *Operational Impact:* lets planners compare drip subsidies, pump upgrades and forecast-based postponement before committing water and electricity.

#fig("farm", "Farm Details drill-through page", [Figure 4.6: Farm Details Drill-Through (plot MM-MD-0773 example)])

#lab[Description:]
Right-clicking a plot in the page 4 schedule and choosing Drill through opens the Farm Details page, filtered to that plot. It shows cards for soil moisture, depletion, stress score, NDVI and days to next irrigation, the full advisory text, a table of plot attributes (location, area, LAI, pH, organic carbon, rainfall, temperature, humidity and coordinates), and a water balance and fertigation table.

#lab[BI Decision Analysis:]
- Plot `MM-MD-0773` (Ankegowdanadoddi, Maddur) has the highest stress score of all 1,000 plots (76.5). Its soil moisture is 0.219 m³/m³ (50.3% depletion), its NDVI is only 0.306, and it sits in the warmest, driest air in the district (24.2°C, 76.2% humidity).
- The page prescribes 80.5 mm gross (592 m³), 19.7 pump hours over 3 power windows and 73.7 kWh. Waiting 3 more days carries a 43.8% yield loss risk for the stress period.
- Because NDVI is below 0.45, the fertigation advice adds a leaf nitrogen test and a split nitrogen dose with the next irrigation.
- By contrast, the least stressed plot, `MM-MD-0879` in Laxmipura (score 16.0, soil moisture 0.256 m³/m³), can wait about 4 days.
- *Operational Impact:* lets a field assistant check one plot's numbers in front of the farmer before the advisory is accepted or overridden.

= 5. Operational Mitigation Strategy

The dashboard is not the final product. The final product is the action taken from the DSS output. The advisory measure maps each tier to a standard response:

- *Irrigate Today:* start pumping in the first available power window, early in the morning, with the stated hours and volume. Prioritise High-stress plots when pumps or power are short.
- *Irrigate in 1 to 3 Days:* keep the pump and power slots booked, re-check the rain forecast, and skip the irrigation if rain is expected.
- *Irrigate in 4 to 7 Days:* no action; re-assess with the next satellite and weather update.
- *No Irrigation Needed:* soil moisture is sufficient; continue monitoring.
- *Fertigation:* low-vigour plots (NDVI below 0.45, 83 plots) receive a split nitrogen dose with the irrigation; the remaining acidic plots (pH below 6.2, 195 plots) are advised to lime and avoid ammonium sulphate; the rest continue scheduled NPK fertigation.

Access is controlled with row-level security. The *Malavalli Field Supervisor* and *Krishnarajpet Field Supervisor* roles see only the plots of their own taluk, which keeps farmer and plot data limited to the staff responsible for it, in line with the use case's privacy and DPDP Act guidance. The advisory text follows the use case's generative AI pattern ("Irrigate tomorrow morning for 2.5 hours") and is the natural input for an LLM layer that translates it into Kannada, Marathi and Hindi. Agronomists keep the final say: the schedule is a recommendation that field staff can confirm or override.

= 6. Data Limitations and Assumptions

- The dataset is a single snapshot with no dates, so the dashboard shows the current state and cannot track moisture or yield over time. Real deployment needs daily sensor or satellite updates.
- Soil moisture is satellite-derived and varies very little (0.218 to 0.256 m³/m³). 793 plots lie within 2 mm of the trigger, so small measurement errors can flip a plot between Irrigate Today and Irrigate in 1 to 3 Days.
- Field capacity, wilting point, root depth, crop coefficient, Hargreaves radiation, pump size, efficiency and the 100 mm farmer practice are assumptions, not measurements. They should be calibrated with KIAAR soil tests and field trials.
- Every plot has the same area (0.7355 ha), so the geofences are fixed-size buffers rather than surveyed field boundaries.
- Rainfall, temperature and humidity come from a coarse weather grid (only 14 to 38 distinct values), and rainfall is a seasonal total rather than a forecast.
- 885 plots have organic carbon of exactly 10, which looks like a modelled default; organic carbon is therefore shown but not used in the advisory.
- 6 plots have imputed NDVI (village median).

= 7. Conclusion

The Sugarcane Irrigation Advisory DSS moves irrigation from habit to measurement. By combining cleaned satellite, weather and soil data for 1,000 plots with a transparent FAO-56 soil water balance, a composite stress score and an automated advisory engine, it shows that 614 plots need water today, mostly in Pandavpura and Mandya taluk, that targeting only those plots halves water use compared with blanket flooding (49.9%, or 66.6% with drip), and that a few millimetres of forecast rain can postpone the whole day's irrigation. The dashboard gives KIAAR and GBL staff one place to see which plots to irrigate, how much water and electricity to plan for and what to tell each farmer, while keeping every recommendation explainable and open to agronomist review.
