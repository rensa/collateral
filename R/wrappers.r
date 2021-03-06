safe_mapper <- function(.f, .mapper, otherwise = NULL, quiet = TRUE, ...) {
  .f <- purrr::as_mapper(.f, ...)
  .f <- purrr::safely(.f, otherwise = NULL, quiet = TRUE)
  results <- .mapper(.f, ...)
  class(results) <- c('safely_mapped', class(results))
  results
}

quiet_mapper <- function(.f, .mapper, ...) {
  .f <- purrr::as_mapper(.f, ...)
  .f <- purrr::quietly(.f)
  results <- .mapper(.f, ...)
  class(results) <- c('quietly_mapped', class(results))
  results
}

peaceful_mapper <- function(.f, .mapper, ...) {
  .f <- purrr::as_mapper(.f, ...)
  .f <- purrr::compose(quietly, safely)(.f)
  results <- .mapper(.f, ...)

  peaceful_flattener <- function(x) {
    if (!is.null(x$result$error)) {
      x$error <- x$result$error
      x$result$error <- NULL
    } else {
      x['error'] <- list(NULL)
    }
    if (!is.null(x$result$result)) {
      x$result <- x$result$result
    } else {
      x['result'] <- list(NULL)
    }
    x
  }
  results <- purrr::modify(results, peaceful_flattener)

  class(results) <- c('peacefully_mapped', class(results))
  results
}

map2_wrapper <- function(.x, .y, .parallel = FALSE) {
  if (.parallel) {
    function(.f, ...)
      furrr::future_map2(.x, .y, .f, ...)
  } else {
    function(.f, ...)
      purrr::map2(.x, .y, .f, ...)
  }
}

map_wrapper <- function(.x, .parallel = FALSE) {
  if (.parallel) {
    function(.f, ...)
      furrr::future_map(.x, .f, ...)
  } else {
    function(.f, ...)
      purrr::map(.x, .f, ...)
  }
}

pmap_wrapper <- function(.l, .parallel = FALSE) {
  if (.parallel) {
    function(.f, ...)
      furrr::future_pmap(.l, .f, ...)
  } else {
    function(.f, ...)
      purrr::pmap(.l, .f, ...)
  }
}

#' Map over a list while capturing side effects.
#'
#' `map_safely()`, `map_quietly()` and `map_peacefully()` are variants of
#' [purrr::map()] that wrap the supplied function `.f` using [purrr::safely()]
#' and/or `purrr::quietly()` in order to capture various side effects. Lists
#' mapped in this way have an associated class added to them, allowing them to
#' succinctly summarise captured side effects when displayed in a tibble.
#'
#'
#'
#' `map_safely()` will summarise the returned list with a fixed-width
#' string of two (spaced) columns:
#' 1. If a `result` component is present, `R` appears, and
#' 1. If an `error` component is present, `E` appears.
#'
#' If either component is missing, an underscore (`_`) appears in its
#' place.
#'
#' Similarly, `map_quietly()` will summarise the returned list with a
#' fixed-width string of four (spaced) columns:
#' 1. If a `result` component is present, `R` appears,
#' 1. If an `output` component is present, `O` appears,
#' 1. If a `messages` component is present, `M` appears, and
#' 1. If a `warnings` component is present, `W` appears.
#'
#'  If any is missing, an underscore (`_`) appears in its
#'  place.
#'
#'  Variants for [iterating over two or more inputs simultaneously](https://purrr.tidyverse.org/reference/map2.html)
#'  are also provided and function identically to their `purrr` counterparts:
#'  1. `map2_safely()`
#'  1. `map2_quietly()`
#'  1. `pmap_safely()`
#'  1. `pmap_quietly()`
#'
#'  Further variants, prefixed by `future_`, allow safe or quiet mapping to
#'  happen in parallel if you have the [`furrr`](https://cran.r-project.org/package=furrr)
#'  package installed:
#'  1. `future_map_safely()`
#'  1. `future_map_quietly()`
#'  1. `future_map2_safely()`
#'  1. `future_map2_quietly()`
#'  1. `future_pmap_safely()`
#'  1. `future_pmap_quietly()`
#'
#' @param .x A list or atomic vector.
#' @param .y A list or atomic vector, of the same length as `.x`.
#' @param .l A list of lists. The length of `.l` determines the number of
#'   arguments that `.f` will be called with. List names will be used if
#'   present.
#' @param .f A function, formula or atomic vector, as specified by
#'   [purrr::as_mapper()].
#' @param otherwise Default value to use when an error occurs.
#' @param quiet Hide errors (`TRUE`, the default), or display them as they
#'   occur?
#' @param ... Other arguments supplied to [purrr::map()] or its variants, or to
#'   [furrr::future_map()] or its variants..
#' @return A list of the same length as `.x`. Each element of the returned list
#'   is itself a named list, structured according to the captured side effects.
#'   The Details section elaborates on these side effects.
#'
#' @name collateral_mappers
#'
#' @examples
#'
#' library(tibble)
#' library(dplyr)
#' library(tidyr)
#' library(collateral)
#'
#' # like map(), these can be used to iterate over vectors or lists
#' list("a", 10, 100) %>% map_safely(log)
#' list(5, -12, 103) %>% map_quietly(log)
#'
#' # if you're using tibbles, you can also iterate over list-columns,
#' # such as nested data frames
#' mtcars %>%
#'   rownames_to_column(var = "car") %>%
#'   as_tibble() %>%
#'   select(car, cyl, disp, wt) %>%
#'   # spike some rows in cyl == 4 to make them fail
#'   mutate(wt = dplyr::case_when(
#'     wt < 2 ~ -wt,
#'     TRUE ~ wt)) %>%
#'   # nest and do some operations quietly()
#'   nest(data = -cyl) %>%
#'   mutate(qlog = map_quietly(data, ~ log(.$wt)))
#'
NULL

# non-parallel (purrr) collateral mappers

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely map
#' @export
map_safely <- function(.x, .f, otherwise = NULL, quiet = TRUE, ...) {
  .map <- map_wrapper(.x)
  safe_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly map
#' @export
map_quietly <- function(.x, .f, ...) {
  .map <- map_wrapper(.x)
  quiet_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper map
#' @export
map_peacefully <- function(.x, .f, ...) {
  .map <- map_wrapper(.x)
  peaceful_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely map2
#' @export
map2_safely <- function(.x, .y, .f, otherwise = NULL, quiet = TRUE, ...) {
  .map2 <- map2_wrapper(.x, .y)
  safe_mapper(.f, .map2, ...)
}


#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly map2
#' @export
map2_quietly <- function(.x, .y, .f, ...) {
  .map2 <- map2_wrapper(.x, .y)
  quiet_mapper(.f, .map2, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper map2
#' @export
map2_peacefully <- function(.x, .y, .f, ...) {
  .map2 <- map2_wrapper(.x, .y)
  peaceful_mapper(.f, .map2, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely pmap
#' @export
pmap_safely <- function(.l, .f, otherwise = NULL, quiet = TRUE, ...) {
  .pmap <- pmap_wrapper(.l)
  safe_mapper(.f, .pmap, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly pmap
#' @export
pmap_quietly <- function(.l, .f, ...) {
  .pmap <- pmap_wrapper(.l)
  quiet_mapper(.f, .pmap, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper pmap
#' @export
pmap_peacefully <- function(.l, .f, ...) {
  .pmap <- pmap_wrapper(.l)
  peaceful_mapper(.f, .pmap, ...)
}

# parallel (furrr) collateral mappers

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely map
#' @export
future_map_safely <- function(.x, .f, otherwise = NULL, quiet = TRUE, ...) {
  .map <- map_wrapper(.x, .parallel = TRUE)
  safe_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly map
#' @export
future_map_quietly <- function(.x, .f, ...) {
  .map <- map_wrapper(.x, .parallel = TRUE)
  quiet_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper map
#' @export
future_map_peacefully <- function(.x, .f, ...) {
  .map <- map_wrapper(.x, .parallel = TRUE)
  peaceful_mapper(.f, .map, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely map2
#' @export
future_map2_safely <- function(.x, .y, .f, otherwise = NULL, quiet = TRUE, ...) {
  .map2 <- map2_wrapper(.x, .y, .parallel = TRUE)
  safe_mapper(.f, .map2, ...)
}


#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly map2
#' @export
future_map2_quietly <- function(.x, .y, .f, ...) {
  .map2 <- map2_wrapper(.x, .y, .parallel = TRUE)
  quiet_mapper(.f, .map2, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper map2
#' @export
future_map2_peacefully <- function(.x, .y, .f, ...) {
  .map2 <- map2_wrapper(.x, .y, .parallel = TRUE)
  peaceful_mapper(.f, .map2, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper safely pmap
#' @export
future_pmap_safely <- function(.l, .f, otherwise = NULL, quiet = TRUE, ...) {
  .pmap <- pmap_wrapper(.l, .parallel = TRUE)
  safe_mapper(.f, .pmap, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper quietly pmap
#' @export
future_pmap_quietly <- function(.l, .f, ...) {
  .pmap <- pmap_wrapper(.l, .parallel = TRUE)
  quiet_mapper(.f, .pmap, ...)
}

#' @rdname collateral_mappers
#' @importFrom purrr as_mapper pmap
#' @export
future_pmap_peacefully <- function(.l, .f, ...) {
  .pmap <- pmap_wrapper(.l, .parallel = TRUE)
  peaceful_mapper(.f, .pmap, ...)
}
