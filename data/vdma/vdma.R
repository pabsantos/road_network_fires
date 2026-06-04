arquivos = list.files("data_raw/vdma", full.names = TRUE)
names(arquivos) = stringr::str_extract(basename(arquivos), "\\d{4}")

# a aba de dados não é fixa: em 2021 vem antes da de "Metadados".
# escolhe sempre a aba que não é a de metadados.
ler_vdma = function(arquivo) {
    abas = readxl::excel_sheets(arquivo)
    aba_dados = setdiff(abas, "Metadados")[1]
    readxl::read_excel(arquivo, sheet = aba_dados)
}

list_dfs = purrr::map(arquivos, ler_vdma)

list_dfs[["2020"]] = list_dfs[["2020"]] |>
    dplyr::mutate(dplyr::across(A_C:VMDa_D, ~ as.numeric(.x)))

# 2021 vem no formato PNCT (schema diferente): renomeia VMDA_AB/BA -> VMDa_C/D
# e mapeia o código SRE para id_trecho_ via o vl_codigo do SNV (1:1).
# Há sub-trechos por código SRE, então agrega por trecho com a média da VMDa.
crosswalk = readRDS("data/snv/snv.rds") |>
    sf::st_drop_geometry() |>
    dplyr::distinct(vl_codigo, id_trecho_)

list_dfs[["2021"]] = list_dfs[["2021"]] |>
    dplyr::rename(
        vl_codigo = `CODIGO_SNV-SRE`,
        VMDa_C = VMDA_AB,
        VMDa_D = VMDA_BA
    ) |>
    dplyr::inner_join(crosswalk, by = "vl_codigo") |>
    dplyr::summarise(
        VMDa_C = mean(as.numeric(VMDa_C), na.rm = TRUE),
        VMDa_D = mean(as.numeric(VMDa_D), na.rm = TRUE),
        .by = id_trecho_
    )

df_vdma = dplyr::bind_rows(list_dfs, .id = "ano")
saveRDS(df_vdma, "data/vdma/vdma.rds")

# Fonte: Plano Nacional de Contagem de Tráfego (DNIT)
