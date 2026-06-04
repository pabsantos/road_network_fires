prepare_snv <- function(snv, crs) {
    sf::st_transform(snv, crs = crs)
}

prepare_prf <- function(prf, ano, crs_origem, crs_destino) {
    prf |>
        dplyr::filter(
            lubridate::year(data_inversa) == ano,
            !is.na(longitude),
            !is.na(latitude)
        ) |>
        sf::st_as_sf(coords = c("longitude", "latitude"), crs = crs_origem) |>
        sf::st_transform(crs = crs_destino)
}

prepare_focos <- function(focos, ano, crs_origem, crs_destino) {
    focos |>
        dplyr::filter(
            lubridate::year(data_pas) == ano,
            !is.na(lon),
            !is.na(lat)
        ) |>
        sf::st_as_sf(coords = c("lon", "lat"), crs = crs_origem) |>
        sf::st_transform(crs = crs_destino)
}

filter_vdma <- function(vdma, ano) {
    vdma |>
        dplyr::filter(.data$ano == as.character(.env$ano)) |>
        # a VDMA traz linhas duplicadas (cópias exatas) por id_trecho_;
        # remove para não inflar n_focos/n_sinistros no left_join
        dplyr::distinct(id_trecho_, .keep_all = TRUE)
}

count_focos <- function(snv_conic, focos_conic, buffer) {
    snv_buffers <- sf::st_buffer(snv_conic, dist = buffer)
    lengths(sf::st_intersects(snv_buffers, focos_conic))
}

count_sinistros <- function(snv_conic, prf_conic) {
    idx <- sf::st_nearest_feature(prf_conic, snv_conic)

    data.frame(id_trecho_ = snv_conic$id_trecho_[idx]) |>
        dplyr::count(id_trecho_, name = "n_sinistros")
}

build_dataset <- function(
    snv_conic,
    prf_conic,
    focos_conic,
    vdma_ano,
    ano,
    buffer
) {
    snv_conic$n_focos <- count_focos(snv_conic, focos_conic, buffer)

    snv_conic |>
        dplyr::left_join(
            count_sinistros(snv_conic, prf_conic),
            by = "id_trecho_"
        ) |>
        dplyr::left_join(vdma_ano, by = "id_trecho_") |>
        dplyr::mutate(
            ano = .env$ano,
            fluxo = (VMDa_C + VMDa_D) * 365,
            dist_m = as.numeric(sf::st_length(geometry))
        ) |>
        tidyr::replace_na(list(n_sinistros = 0)) |>
        dplyr::select(id_trecho_, ano, n_focos, n_sinistros, fluxo, dist_m)
}
