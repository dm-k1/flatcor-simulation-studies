## =====================================================================
##  The methods' colours in the figures: one colour per prior, the
##  references in grey (the methods: R/project/shared_by_studies/comparison_methods.R)
## =====================================================================

## Colour for the figures: one colour per prior, the references in grey
method_colours <- c(
  `flat partial r` = "#0072B2",
  `flat R-squared` = "#009E73",
  `flat R` = "#D55E00",
  `JZS` = "grey25",
  `Zellner` = "grey60"
)
method_colour_of <- function(method) {
  starts <- names(method_colours)[startsWith(method, names(method_colours))]
  if (length(starts) == 0) "black" else method_colours[[starts[1]]]
}

## The colour scale for a figure, with the methods in a fixed order
method_scales <- function(methods) {
  methods <- unique(as.character(methods))
  order_of_colours <- c("#0072B2", "#D55E00", "#009E73", "grey25", "grey60", "black")
  methods <- methods[order(match(sapply(methods, method_colour_of), order_of_colours))]

  list(
    scale_colour_manual(
      values = setNames(sapply(methods, method_colour_of), methods),
      breaks = methods,
      name = NULL
    ),
    theme(legend.position = "bottom", legend.key.width = unit(2.5, "lines")),
    guides(colour = guide_legend(nrow = 1, override.aes = list(alpha = 1)))
  )
}
