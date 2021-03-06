

# == title 
# Class for a single annotation
#
# == details
# A complex heatmap always has more than one annotations on rows and columns. Here
# the `SingleAnnotation-class` defines the basic unit of annotations.
# The most simple annotation is one row or one column grids in which different colors
# represent different classes of the data. The annotation can also be more complex
# graphics, such as a boxplot that shows data distribution in corresponding row or column.
#
# The `SingleAnnotation-class` is used for storing data for a single annotation and provides
# methods for drawing annotation graphics.
#
# == methods
# The `SingleAnnotation-class` provides following methods:
#
# - `SingleAnnotation`: constructor method
# - `draw,SingleAnnotation-method`: draw the single annotation.
#
# == seealso
# The `SingleAnnotation-class` is always used internally. The public `HeatmapAnnotation-class`
# contains a list of `SingleAnnotation-class` objects and is used to add annotation graphics on heatmaps.
# 
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
SingleAnnotation = setClass("SingleAnnotation",
	slots = list(
		name = "character",
		color_mapping = "ANY",  # a ColorMapping object or NULL
		legend_param = "ANY", # a list or NULL, it contains parameters for color_mapping_legend
		fun = "ANY",
		show_legend = "logical",
		which = "character",
		name_to_data_vp = "logical",
		name_param = "list",
        is_anno_matrix = "logical",
        color_is_random = "logical",
        width = "ANY",
        height = "ANY",
        extended = "ANY",
        subsetable = "logical"
	),
	prototype = list(
		color_mapping = NULL,
		fun = function(index) NULL,
		show_legend = TRUE,
        color_is_random = FALSE,
		name_to_data_vp = FALSE,
        extended = unit(c(0, 0, 0, 0), "mm"),
        subsetable = FALSE
	)
)

# == title
# Constructor method for SingleAnnotation class
#
# == param
# -name name for this annotation. If it is not specified, an internal name is assigned.
# -value A vector of discrete or continuous annotation.
# -col colors corresponding to ``value``. If the mapping is discrete mapping, the value of ``col``
#      should be a vector; If the mapping is continuous mapping, the value of ``col`` should be 
#      a color mapping function. 
# -fun a self-defined function to add annotation graphics. The argument of this function should only 
#      be a vector of index that corresponds to rows or columns.
# -na_col color for ``NA`` values in simple annotations.
# -which is the annotation a row annotation or a column annotation?
# -show_legend if it is a simple annotation, whether show legend when making the complete heatmap.
# -gp Since simple annotation is represented as a row of grids. This argument controls graphic parameters for the simple annotation.
# -legend_param parameters for the legend. See `color_mapping_legend,ColorMapping-method` for options.
# -show_name whether show annotation name
# -name_gp graphic parameters for annotation name
# -name_offset offset to the annotation, a `grid::unit` object
# -name_side 'right' and 'left' for column annotations and 'top' and 'bottom' for row annotations
# -name_rot rotation of the annotation name, can only take values in ``c(00, 90, 180, 270)``.
#
# == details
# The most simple annotation is one row or one column grids in which different colors
# represent different classes of the data. Here the function use `ColorMapping-class`
# to process such simple annotation. ``value`` and ``col`` arguments controls values and colors
# of the simple annotation and a `ColorMapping-class` object will be constructed based on ``value`` and ``col``.
#
# ``fun`` is used to construct a more complex annotation. Users can add any type of annotation graphics
# by implementing a function. The only input argument of ``fun`` is a index
# of rows or columns which is already adjusted by the clustering. In the package, there are already
# several annotation graphic function generators: `anno_points`, `anno_histogram` and `anno_boxplot`.
#
# In the case that row annotations are splitted by rows, ``index`` corresponding to row orders in each row-slice
# and ``fun`` will be applied on each of the row slices.
#
# One thing that users should be careful is the difference of coordinates when the annotation is a row
# annotation or a column annotation. 
#
# == seealso
# There are following built-in annotation functions that can be used to generate complex annotations: 
# `anno_points`, `anno_barplot`, `anno_histogram`, `anno_boxplot`, `anno_density`, `anno_text` and `anno_link`.
# 
# == value
# A `SingleAnnotation-class` object.
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
SingleAnnotation = function(name, value, col, fun, 
	na_col = "grey",
	which = c("column", "row"), 
	show_legend = TRUE, 
	gp = gpar(col = NA), 
	legend_param = list(),
	show_name = TRUE, 
	name_gp = gpar(fontsize = 12),
	name_offset = unit(2, "mm"),
	name_side = ifelse(which == "column", "right", "bottom"),
    name_rot = ifelse(which == "column", 0, 90),
    width = NULL, height = NULL) {

	which = match.arg(which)[1]
    .ENV$current_annotation_which = which
    on.exit(.ENV$current_SingleAnnotation_which <- NULL)

    # re-define some of the argument values according to global settings
    called_args = names(as.list(match.call())[-1])
    if("legend_param" %in% called_args) {
        for(opt_name in setdiff(c("title_gp", "title_position", "labels_gp", "grid_width", "grid_height", "grid_border"), names(legend_param))) {
            opt_name2 = paste0("annotation_legend_", opt_name)
            if(!is.null(ht_global_opt(opt_name2)))
                legend_param[[opt_name]] = ht_global_opt(opt_name2)
        }
    } else {
        for(opt_name in c("title_gp", "title_position", "labels_gp", "grid_width", "grid_height", "grid_border")) {
            opt_name2 = paste0("annotation_legend_", opt_name)
            if(!is.null(ht_global_opt(opt_name2)))
                legend_param[[opt_name]] = ht_global_opt(opt_name2)
        }
    }

	.Object = new("SingleAnnotation")
	.Object@which = which
    
	if(missing(name)) {
        name = paste0("anno", get_annotation_index() + 1)
        increase_annotation_index()
    }
    .Object@name = name

    if(!name_rot %in% c(0, 90, 180, 270)) {
        stop("`name_rot` can only take values in c(0, 90, 180, 270)")
    }

    .Object@is_anno_matrix = FALSE
    use_mat_column_names = FALSE
    if(!missing(value)) {
        if(is.logical(value)) {
            value = as.character(value)
        }
        if(is.factor(value)) {
            value = as.vector(value)
        }
        if(is.matrix(value)) {
            .Object@is_anno_matrix = TRUE
            attr(.Object@is_anno_matrix, "column_names") = colnames(value)
            attr(.Object@is_anno_matrix, "k") = ncol(value)
            if(length(colnames(value))) {
                use_mat_column_names = TRUE
            }
            use_mat_nc = ncol(value)
        }
    }

    is_name_offset_called = !missing(name_offset)
    is_name_rot_called = !missing(name_rot)
    anno_fun_extend = unit(c(0, 0, 0, 0), "mm")
    if(!missing(fun)) {
        if(inherits(fun, "AnnotationFunction")) {
            anno_fun_extend = fun@extended
        }
    }

    anno_name = name
    if(which == "column") {
    	if(!name_side %in% c("left", "right")) {
    		stop("`name_side` should be 'left' or 'right' when it is a column annotation.")
    	}
    	if(name_side == "left") {
            if(anno_fun_extend[[2]] > 0) {
                if(!is_name_offset_called) {
                    name_offset = name_offset + anno_fun_extend[2]
                }
                if(!is_name_rot_called) {
                    name_rot = 90
                }
            }

            if(use_mat_column_names) {
                name_x = unit(rep(0, use_mat_nc), "npc") - name_offset
                name_y = unit((use_mat_nc - seq_len(use_mat_nc) + 0.5)/use_mat_nc, "npc")

                anno_name = colnames(value)
            } else {
                name_x = unit(0, "npc") - name_offset
                name_y = unit(0.5, "npc")
            }
            if(name_rot == 0) {
                name_just = "right"
            } else if(name_rot == 90) {
                name_just = "bottom"
            } else if(name_rot == 180) {
                name_just = "left"
            } else {
                name_just = "top"
            }
    	} else {
            if(anno_fun_extend[[4]] > 0) {
                if(!is_name_offset_called) {
                    name_offset = name_offset + anno_fun_extend[4]
                }
                if(!is_name_rot_called) {
                    name_rot = 90
                }
            }

            if(use_mat_column_names) {
                name_x = unit(rep(1, use_mat_nc), "npc") + name_offset
                name_y = unit((use_mat_nc - seq_len(use_mat_nc) + 0.5)/use_mat_nc, "npc")

                anno_name = colnames(value)
            } else {
        		name_x = unit(1, "npc") + name_offset
        		name_y = unit(0.5, "npc")
            }
            if(name_rot == 0) {
                name_just = "left"
            } else if(name_rot == 90) {
                name_just = "top"
            } else if(name_rot == 180) {
                name_just = "right"
            } else {
                name_just = "bottom"
            }
    	}
    } else if(which == "row") {
    	if(!name_side %in% c("top", "bottom")) {
    		stop("`name_side` should be 'left' or 'right' when it is a column annotation.")
    	}
    	if(name_side == "top") {
            if(anno_fun_extend[[3]] > 0) {
                if(!is_name_offset_called) {
                    name_offset = name_offset + anno_fun_extend[3]
                }
                if(!is_name_rot_called) {
                    name_rot = 0
                }
            }

            if(use_mat_column_names) {
                name_x = unit((seq_len(use_mat_nc) - 0.5)/use_mat_nc, "npc")
                name_y = unit(rep(1, use_mat_nc), "npc") + name_offset

                anno_name = colnames(value)
            } else {
        		name_x = unit(0.5, "npc")
        		name_y = unit(1, "npc") + name_offset
            }
            if(name_rot == 0) {
                name_just = "bottom"
            } else if(name_rot == 90) {
                name_just = "left"
            } else if(name_rot == 180) {
                name_just = "top"
            } else {
                name_just = "right"
            }
    	} else {
            if(anno_fun_extend[[1]] > 0) {
                if(!is_name_offset_called) {
                    name_offset = name_offset + anno_fun_extend[1]
                }
                if(!is_name_rot_called) {
                    name_rot = 0
                }
            }
            if(use_mat_column_names) {
                name_x = unit((seq_len(use_mat_nc) - 0.5)/use_mat_nc, "npc")
                name_y = unit(rep(0, use_mat_nc), "npc") - name_offset

                anno_name = colnames(value)
            } else {
        		name_x = unit(0.5, "npc")
        		name_y = unit(0, "npc") - name_offset
            }
            if(name_rot == 0) {
                name_just = "top"
            } else if(name_rot == 90) {
                name_just = "right"
            } else if(name_rot == 180) {
                name_just = "bottom"
            } else {
                name_just = "left"
            }
    	}
    }
    name_param = list(show = show_name,
                      label = anno_name,
					  x = name_x,
					  y = name_y,
                      offset = name_offset,
					  just = name_just,
                      gp = check_gp(name_gp),
                      rot = name_rot,
                      side = name_side)

    # get defaults for name settings
    extended = unit(c(0, 0, 0, 0), "mm")
    if(name_param$show) {
        if(which == "column") {
            if(name_param$rot == 0) {
                text_width = convertWidth(grobWidth(textGrob(name_param$label, gp = name_gp)) + name_param$offset, "mm", valueOnly = TRUE)
            } else {
                text_width = convertHeight(grobHeight(textGrob(name_param$label, gp = name_gp)) + name_param$offset, "mm", valueOnly = TRUE)
            }
            if(name_param$side == "left") {
                extended[[2]] = text_width
            } else if(name_param$side == "right") {
                extended[[4]] = text_width
            }
        } else if(which == "row") {
            if(name_param$rot == 0) {
                text_width = convertHeight(grobHeight(textGrob(name_param$label, gp = name_gp, rot = name_param$rot)) + name_param$offset, "mm", valueOnly = TRUE)
            } else {
                text_width = convertHeight(grobHeight(textGrob(name_param$label, gp = name_gp, rot = name_param$rot)) + name_param$offset, "mm", valueOnly = TRUE)
            }
            if(name_param$side == "bottom") {
                extended[[1]] = text_width
            } else if(name_param$side == "top") {
                extended[[3]] = text_width
            }
        }
        for(i in 1:4) {
            extended[[i]] = max(anno_fun_extend[[i]], extended[[i]])
        }
        .Object@extended = extended
    }

    .Object@name_param = name_param

    gp = check_gp(gp)
    if(!is.null(gp$fill)) {
    	stop("You should not set `fill`.")
    }

    if(missing(fun)) {
        color_is_random = FALSE
    	if(missing(col)) {
    		col = default_col(value)
            color_is_random = TRUE
    	}
    	if(is.atomic(col)) {
    	    if(is.null(names(col))) {
                if(is.factor(value)) {
                    names(col) = levels(value)
                } else {
                    names(col) = unique(value)
                }
            }
            col = col[intersect(c(names(col), "_NA_"), as.character(value))]
    		if("_NA_" %in% names(col)) {
    			na_col = col["_NA_"]
    			col = col[names(col) != "_NA_"]
    		}
            color_mapping = ColorMapping(name = name, colors = col, na_col = na_col)
        } else if(is.function(col)) {
            color_mapping = ColorMapping(name = name, col_fun = col, na_col = na_col)
        }

        .Object@color_mapping = color_mapping
        .Object@color_is_random = color_is_random
        if(is.null(legend_param)) legend_param = list()
        .Object@legend_param = legend_param
        value = value

        .Object@fun = anno_simple(value, col = color_mapping, which = which, na_col = na_col, gp = gp)
        if(missing(width)) {
            .Object@width = .Object@fun@width
        } else {
            .Object@width = width
        }
        if(missing(height)) {
            .Object@height = .Object@fun@height
        } else {
            .Object@height = height
        }
		
		.Object@show_legend = show_legend
        .Object@subsetable = TRUE
    } else {
        
        if(inherits(fun, "AnnotationFunction")) {
        	f_which = fun@which
        	if(!is.null(f_which)) {
        		fun_name = fun@fun_name
        		if(f_which != which) {
        			stop(paste0("You are putting ", fun_name, "() as ", which, " annotations, you need to set 'which' argument to '", which, "' as well,\nor use the helper function ", which, "_", fun_name, "()."))
        		}
        	}
        } else {
            if(length(formals(fun)) == 1) {
                formals(fun) = alist(index = , k = 1, n = 1)
            }
        }
    	.Object@fun = fun
    	.Object@show_legend = FALSE
        if(inherits(fun, "AnnotationFunction")) {
            .Object@width = .Object@fun@width
            .Object@height = .Object@fun@height
            .Object@subsetable = TRUE
        } else {
            if(which == "column") {
                if(missing(height)) {
                    height = unit(1, "cm")
                }
                if(missing(width)) {
                    width = unit(1, "npc")
                }
            }
            if(which == "row") {
                if(missing(width)) {
                    width = unit(1, "cm")
                }
                if(missing(height)) {
                    height = unit(1, "npc")
                }
            }
            .Object@width = width
            .Object@height = height
        }

    }

    return(.Object)
}

# == title
# Draw the single annotation
#
# == param
# -object a `SingleAnnotation-class` object.
# -index a vector of orders
# -k if row annotation is splitted, the value identifies which row slice. It is only used for the names of the viewport
#    which contains the annotation graphics.
# -n total number of row slices
#
# == details
# A viewport is created.
#
# The graphics would be different depending the annotation is a row annotation or a column annotation.
#
# == value
# No value is returned.
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
setMethod(f = "draw",
	signature = "SingleAnnotation",
	definition = function(object, index, k = 1, n = 1, test = FALSE) {

    if(is.character(test)) {
        test2 = TRUE
    } else {
        test2 = test
    }
    ## it draws annotation names, create viewports with names
    if(test2) {
        grid.newpage()
        pushViewport(viewport(width = unit(1, "npc") - unit(4, "cm"), 
                              height = unit(1, "npc") - unit(4, "cm")))
    }

    if(missing(index)) {
        if(has_AnnotationFunction(object)) {
            index = seq_len(object@fun@n)
        }
    }

    anno_height = object@height
    anno_width = object@width
    
	# names should be passed to the data viewport
	if(has_AnnotationFunction(object)) {
        data_scale = list(x = c(0.5, length(index) + 0.5), y = object@fun@data_scale)
    } else {
        data_scale = list(x = c(0, 1), y = c(0, 1))
    }
	pushViewport(viewport(width = anno_width, height = anno_height, 
        name = paste("annotation", object@name, k, sep = "_"),
        xscale = data_scale$x, yscale = data_scale$y))
    if(has_AnnotationFunction(object)) {
        fun = object@fun[index]
        if(!is.null(fun@var_env$axis)) {
            if(fun@var_env$axis && n > 1) {
                if(object@which == "row") {
                    if(k == n && fun@var_env$axis_param$side == "bottom") {
                        fun@var_env$axis = TRUE
                    } else if(k == 1 && fun@var_env$axis_param$side == "top") {
                        fun@var_env$axis = TRUE
                    } else {
                        fun@var_env$axis = FALSE
                    }
                } else if(object@which == "column") {
                    if(k == 1 && fun@var_env$axis_param$side == "left") {
                        fun@var_env$axis = TRUE
                    } else if(k == n && fun@var_env$axis_param$side == "right") {
                        fun@var_env$axis = TRUE
                    } else {
                        fun@var_env$axis = FALSE
                    }
                }
            }
        }
        draw(fun)
    } else {
        object@fun(index, k, n)
    }
	
	# add annotation name
    draw_name = object@name_param$show
	if(object@name_param$show && n > 1) {
        if(object@which == "row") {
            if(k == n && object@name_param$side == "bottom") {
                draw_name = TRUE
            } else if(k == 1 && object@name_param$side == "top") {
                draw_name = TRUE
            } else {
                draw_name = FALSE
            }
        } else if(object@which == "column") {
            if(k == 1 && object@name_param$side == "left") {
                draw_name = TRUE
            } else if(k == n && object@name_param$side == "right") {
                draw_name = TRUE
            } else {
                draw_name = FALSE
            }
        }
    }

    if(draw_name) {
        if(is_matrix_annotation(object)) {
            if(!is.null(attr(object@is_anno_matrix, "column_names"))) {
                anno_mat_column_names = attr(object@is_anno_matrix, "column_names")
                grid.text(anno_mat_column_names, x = object@name_param$x, y = object@name_param$y, just = object@name_param$just, 
                    rot = object@name_param$rot, gp = object@name_param$gp)
            } else {
                if(object@which == "column") {
                    grid.text(object@name, x = object@name_param$x[1], y = unit(0.5, "npc"), just = object@name_param$just, 
                        rot = object@name_param$rot, gp = object@name_param$gp)
                } else {
                    grid.text(object@name, x = unit(0.5, "npc"), y = object@name_param$y[1], just = object@name_param$just, 
                        rot = object@name_param$rot, gp = object@name_param$gp)
                }
            }
        } else {
    		grid.text(object@name, x = object@name_param$x, y = object@name_param$y, just = object@name_param$just, 
    			rot = object@name_param$rot, gp = object@name_param$gp)
        }
    }
	
    if(test2) {
        grid.text(test, y = unit(1, "npc") + unit(2, "mm"), just = "bottom")
        grid.rect(unit(0, "npc") - object@extended[2], unit(0, "npc") - object@extended[1], 
            width = unit(1, "npc") + object@extended[2] + object@extended[4],
            height = unit(1, "npc") + object@extended[1] + object@extended[3],
            just = c("left", "bottom"), gp = gpar(fill = "transparent", col = "red", lty = 2))
    }

	upViewport()

    if(test2) {
        upViewport()
    }
})

# == title
# Print the SingleAnnotation object
#
# == param
# -object a `SingleAnnotation-class` object.
#
# == value
# No value is returned.
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
setMethod(f = "show",
	signature = "SingleAnnotation",
	definition = function(object) {
	
    if(is_fun_annotation(object)) {
        if(has_AnnotationFunction(object)) {
            fun_name = object@fun@fun_name
            fun_name = paste0(fun_name, "()")
        } else {
            fun_name = "self-defined"
        }
		cat("A single annotation with", fun_name, "function\n")
		cat("  name:", object@name, "\n")
		cat("  position:", object@which, "\n")
        cat("  no legend\n")
        if(has_AnnotationFunction(object)) {
            n = object@fun@n
            if(!is.null(n)) cat("  items:", n, "\n")
        }  
	} else {
		cat("A single annotation with", object@color_mapping@type, "color mapping\n")
		cat("  name:", object@name, "\n")
		cat("  position:", object@which, "\n")
		cat("  show legend:", object@show_legend, "\n")
        cat("  items:", object@fun@n, "\n")
        if(is_matrix_annotation(object)) {
            cat("  a matrix with", attr(object@is_anno_matrix, "k"), "columns\n")
        }
        if(object@color_is_random) {
            cat("  color is randomly generated\n")
        }
	}

    cat("  width:", as.character(object@width), "\n")
    cat("  height:", as.character(object@height), "\n")
    cat("  this object is", ifelse(object@subsetable, "\b", "not"), "subsetable\n")
    dirt = c("bottom", "left", "top", "right")
    for(i in 1:4) {
        if(!identical(unit(0, "mm"), object@extended[i])) {
            cat(" ", as.character(object@extended[i]), "extension on the", dirt[i], "\n")
        }
    }
})


is_simple_annotation = function(single_anno) {
    !is_fun_annotation(single_anno) && !is_matrix_annotation(single_anno)
}

is_matrix_annotation = function(single_anno) {
    single_anno@is_anno_matrix
}

is_fun_annotation = function(single_anno) {
    is.null(single_anno@color_mapping)
}

has_AnnotationFunction = function(single_anno) {
    if(is.null(single_anno@fun)) {
        FALSE
    } else {
        inherits(single_anno@fun, "AnnotationFunction")
    }
}


## subset method for .SingleAnnotation-class
## column annotation only allows column subsetting and row annotaiton only allows row subsetting

"[.SingleAnnotation" = function(x, i) {
    # only allow subsetting for anno_* functions defined in ComplexHeatmap
    if(nargs() == 2) {
        x2 = x
        if(inherits(x@fun, "AnnotationFunction")) {
            if(x@fun@subsetable) {
                x2@fun = x@fun[i]
                return(x2)
            }
        }
        stop("This SingleAnnotation object is not allowed for subsetting.")

    } else if(nargs() == 1) {
        return(x)
    }
}


setMethod(f = "copy_all",
    signature = "SingleAnnotation",
    definition = function(object) {

    x2 = object
    if(inherits(object@fun, "AnnotationFunction")) {
        x2@fun = object@fun[seq_len(object@fun@n)]
        return(x2)
    } else {
        return(x2)
    }
})
