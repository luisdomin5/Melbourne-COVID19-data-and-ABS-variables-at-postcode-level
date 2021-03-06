library(tidyverse)
library(sf)
library(absmapsdata)
library(plotly)
library(crosstalk)
library(readxl)
library(googlesheets4)

# STEP  Read 6 August COVID data from Age article by Butt and Stehle
# https://www.theage.com.au/national/victoria/victoria-coronavirus-data-find-the-number-of-active-covid-19-cases-in-your-postcode-20200731-p55hg2.html

cases <- "https://docs.google.com/spreadsheets/d/1oxJt0BBPzk-w2Gn1ImO4zASBCdqeeLJRwHEA4DASBFQ/edit#gid=0" %>%
  read_sheet(sheet = "Data (August 6)") %>%
  mutate(Postcode = as.character(Postcode)) %>%
  rename(
    Confirmed = "Confirmed cases (ever)",
    Active = "Active cases (current)"
  )

# STEP 02 get list of Melb postcodes and suburb names
# Copypasta from the Butt and Stehle article
# Make suburb names more readable

melb_names <- "melbourne.postcode.list.csv" %>%
  read_csv() %>%
  rename(Suburb = `City/ Town`) %>%
  mutate(
    Postcode = as.character(Postcode),
    Suburb = iconv(Suburb, "utf-8", "ascii", sub = " "),
    Suburb = str_replace_all(Suburb, "melbourne", "Melbourne")
  ) %>%
  filter(!Postcode %in% c("Unknown", "Others")) %>%
  select(-State, -District)

# STEP 03 extract shapes from absmaps
# absmaps data - look at postcode level - melb postcodes only
# add melbourne features

mapdata <- postcode2016 %>%
  filter(postcode_2016 %in% melb_names$Postcode) %>%
  rename(Postcode = postcode_2016)

# Step 04 add in case data to melbourne shape data

dat <- mapdata %>%
  left_join(melb_names, by = "Postcode") %>%
  left_join(cases, by = "Postcode") %>%
  replace_na(list(Confirmed = 0))

# Step 05
# determine layout and plot
# visualise to see that it makes sense

g <- list(
  showlegend = FALSE,
  showframe = FALSE,
  showcoastlines = FALSE,
  projection = list(type = "Mercator")
)

dat %>%
  plot_geo(
    split = ~Postcode, showlegend = FALSE, hoverinfo = "text",
    text = ~ paste("Area:", Suburb, "<br>", "Cases:", Confirmed)
  ) %>%
  add_sf(
    color = ~Confirmed,
    hoveron = "points+fills"
  ) %>%
  layout(geo = g)

saveRDS(dat, "Melbourne_case_data.RDS")

# Download ABS Census postcode level data from the ABS website.
# The following options were selected from https://datapacks.censusdata.abs.gov.au/datapacks/:
#  2016 Census Datapacks > General Community > Profile > Postal Areas > Vic

temp <- tempfile()
"https://www.censusdata.abs.gov.au/CensusOutput/copsubdatapacks.nsf/All%20docs%20by%20catNo/2016_GCP_POA_for_Vic/$File/2016_GCP_POA_for_Vic_short-header.zip?OpenElement&key=ee324574-4a37-9d0e-b6ff-66e2d667a73f" %>%
  download.file(temp)
unzip(temp, exdir = "./2016_GCP_POA_for_Vic_short-header")
unlink(temp)

