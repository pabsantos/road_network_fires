list_dfs = purrr::map(
    list.files("data_raw/vdma", full.names = TRUE),
    readxl::read_excel,
    sheet = 2
)

list_dfs[[1]] = list_dfs[[1]] |>
    dplyr::mutate(dplyr::across(A_C:VMDa_D, ~ as.numeric(.x)))

df_vdma = purrr::reduce(list_dfs, dplyr::bind_rows)
saveRDS(df_vdma, "data/vdma/vdma.rds")

# Fonte: Plano Nacional de Contagem de Tráfego (DNIT)
