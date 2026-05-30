df_focos = readr::read_csv(list.files("data_raw/focos/", full.names = TRUE))
saveRDS(df_focos, file = "data/focos/focos.rds")

# Programa Queimadas, INPE, focos pelo satélite AQUA
