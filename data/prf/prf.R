df_sinistros = readr::read_csv2(
    list.files("data_raw/prf/", full.names = TRUE),
    locale = readr::locale(encoding = "latin1"),
    # lidas como texto pois o separador decimal varia entre os anos
    # (vírgula em 2020-2023, ponto em 2024) e o read_csv2 as corromperia
    col_types = readr::cols(km = "c", latitude = "c", longitude = "c")
) |>
    dplyr::mutate(dplyr::across(
        c(km, latitude, longitude),
        ~ as.numeric(gsub(",", ".", .x))
    ))

saveRDS(object = df_sinistros, file = "data/prf/prf.rds")

# Fonte: Dados abertos da PRF
