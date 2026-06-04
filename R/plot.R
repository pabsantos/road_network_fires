prepare_br <- function(crs) {
    geobr::read_state(year = 2020) |>
        dplyr::group_by() |>
        dplyr::summarise() |>
        sf::st_transform(crs = crs)
}

mapa_rodovia <- function(taxas, br, var, label, transform) {
    ggplot2::ggplot() +
        ggplot2::geom_sf(
            data = br,
            color = "grey80",
            fill = "white",
            lwd = 0.2
        ) +
        ggplot2::geom_sf(data = taxas, ggplot2::aes(color = .data[[var]])) +
        ggplot2::theme_minimal() +
        ggplot2::scale_color_viridis_c(
            direction = -1,
            option = "magma",
            transform = transform
        ) +
        ggplot2::labs(color = label)
}

salvar_mapas <- function(taxas, br, ano, dir = "plots") {
    specs <- list(
        list(
            var = "fluxo",
            label = "Fluxo de veículos:",
            transform = "identity",
            filtra_fluxo = TRUE
        ),
        list(
            var = "taxa_sinistros",
            label = "Taxa de sinistros:",
            transform = "log1p",
            filtra_fluxo = TRUE
        ),
        list(
            var = "taxa_focos",
            label = "Taxa de focos:",
            transform = "log1p",
            filtra_fluxo = TRUE
        ),
        list(
            var = "n_focos",
            label = "Focos:",
            transform = "identity",
            filtra_fluxo = FALSE
        ),
        list(
            var = "n_sinistros",
            label = "Sinistros:",
            transform = "identity",
            filtra_fluxo = FALSE
        )
    )

    dir.create(dir, showWarnings = FALSE, recursive = TRUE)

    vapply(
        specs,
        function(spec) {
            dados <- if (spec$filtra_fluxo) {
                tidyr::drop_na(taxas, fluxo)
            } else {
                taxas
            }

            mapa <- mapa_rodovia(
                dados,
                br,
                spec$var,
                spec$label,
                spec$transform
            )

            caminho <- file.path(dir, paste0(spec$var, "_", ano, ".png"))
            ggplot2::ggsave(caminho, mapa, width = 7, height = 5, dpi = 300)
            caminho
        },
        character(1)
    )
}
