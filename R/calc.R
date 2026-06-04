calc_taxas <- function(dataset) {
    dataset |>
        dplyr::mutate(
            taxa_sinistros = n_sinistros / (fluxo * dist_m) * 1000 * 1000000,
            taxa_focos = n_focos / (fluxo * dist_m) * 1000 * 1000000
        )
}
