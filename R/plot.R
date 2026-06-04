prepare_br <- function(crs) {
    geobr::read_state(year = 2020) |>
        dplyr::group_by() |>
        dplyr::summarise() |>
        sf::st_transform(crs = crs)
}

mapa_rodovia <- function(
    taxas,
    br,
    var,
    label,
    transform,
    limites,
    breaks = ggplot2::waiver(),
    labels = ggplot2::waiver()
) {
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
            transform = transform,
            limits = limites,
            breaks = breaks,
            labels = labels
        ) +
        ggplot2::labs(color = label)
}

# intervalo global (min/max) de cada variável sobre todos os anos, para que os
# mapas de uma mesma variável compartilhem a escala de cor e sejam comparáveis.
calc_limites <- function(taxas) {
    vars <- c("fluxo", "taxa_sinistros", "taxa_focos", "n_focos", "n_sinistros")
    lapply(stats::setNames(vars, vars), function(v) {
        range(unlist(lapply(taxas, function(t) t[[v]])), na.rm = TRUE)
    })
}

salvar_mapas <- function(taxas, br, ano, limites, dir = "plots") {
    specs <- list(
        list(
            var = "fluxo",
            label = "Fluxo de veículos:",
            transform = "identity",
            filtra_fluxo = TRUE,
            labels = scales::label_number(big.mark = ".", decimal.mark = ",")
        ),
        list(
            var = "taxa_sinistros",
            label = "Taxa de sinistros:",
            transform = "log1p",
            filtra_fluxo = TRUE,
            breaks = c(0, 1, 5, 10, 25, 50, 100)
        ),
        list(
            var = "taxa_focos",
            label = "Taxa de focos:",
            transform = "log1p",
            filtra_fluxo = TRUE,
            breaks = c(0, 1, 2, 4, 6)
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
                spec$transform,
                limites[[spec$var]],
                spec$breaks %||% ggplot2::waiver(),
                spec$labels %||% ggplot2::waiver()
            )

            caminho <- file.path(dir, paste0(spec$var, "_", ano, ".png"))
            ggplot2::ggsave(caminho, mapa, width = 7, height = 5, dpi = 300)
            caminho
        },
        character(1)
    )
}
