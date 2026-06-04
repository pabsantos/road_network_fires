library(targets)

tar_option_set(packages = c(
    "sf",
    "dplyr",
    "tidyr",
    "lubridate",
    "ggplot2",
    "geobr"
))

tar_source()

list(
    tar_target(anos, 2020:2025),

    tar_target(buffer_dist, 500),
    tar_target(crs_original, 4326),
    tar_target(crs_conico, 5880),

    tar_target(snv_path, "data/snv/snv.rds", format = "file"),
    tar_target(prf_path, "data/prf/prf.rds", format = "file"),
    tar_target(focos_path, "data/focos/focos.rds", format = "file"),
    tar_target(vdma_path, "data/vdma/vdma.rds", format = "file"),

    tar_target(snv_conic, prepare_snv(readRDS(snv_path), crs_conico)),
    tar_target(prf_raw, readRDS(prf_path)),
    tar_target(focos_raw, readRDS(focos_path)),
    tar_target(vdma_raw, readRDS(vdma_path)),

    tar_target(
        prf_conic,
        prepare_prf(prf_raw, anos, crs_original, crs_conico),
        pattern = map(anos),
        iteration = "list"
    ),
    tar_target(
        focos_conic,
        prepare_focos(focos_raw, anos, crs_original, crs_conico),
        pattern = map(anos),
        iteration = "list"
    ),
    tar_target(
        vdma_ano,
        filter_vdma(vdma_raw, anos),
        pattern = map(anos),
        iteration = "list"
    ),

    tar_target(
        dataset,
        build_dataset(
            snv_conic,
            prf_conic,
            focos_conic,
            vdma_ano,
            anos,
            buffer_dist
        ),
        pattern = map(prf_conic, focos_conic, vdma_ano, anos),
        iteration = "list"
    ),

    tar_target(br_conic, prepare_br(crs_conico)),

    tar_target(
        taxas,
        calc_taxas(dataset),
        pattern = map(dataset),
        iteration = "list"
    ),
    tar_target(limites, calc_limites(taxas)),
    tar_target(
        mapas,
        salvar_mapas(taxas, br_conic, anos, limites),
        pattern = map(taxas, anos),
        format = "file"
    )
)
