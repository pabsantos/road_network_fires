df_sinistros = readr::read_csv2(list.files("data_raw/prf/", full.names = TRUE))
saveRDS(object = df_sinistros, file = "data/prf/prf.rds")

# Fonte: Dados abertos da PRF
