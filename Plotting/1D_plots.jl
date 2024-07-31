using Plots
using Printf
using Measures

# Create a function to generate the 1D plot
function create_1D_plot!(p, data, x, label, min_val, max_val, title_font_size, axis_font_size, xlabel, ylabel, show_labels, show_ticks, show_legend)
    if x === nothing
        plot!(
            p,
            data, 
            label=label,
            ylim=(min_val, max_val), 
            xlabel=show_labels ? xlabel : "", 
            ylabel=show_labels ? ylabel : "", 
            legend=show_legend,
            titlefontsize=title_font_size, 
            guidefontsize=axis_font_size,
            tickfontsize=axis_font_size,
            xticks=show_ticks ? :auto : :none,
            yticks=show_ticks ? :auto : :none,
        )
    else
        plot!(
            p,
            x, data, 
            label=label,
            ylim=(min_val, max_val), 
            xlabel=show_labels ? xlabel : "", 
            ylabel=show_labels ? ylabel : "", 
            legend=show_legend,
            titlefontsize=title_font_size, 
            guidefontsize=axis_font_size,
            tickfontsize=axis_font_size,
            xticks=show_ticks ? :auto : :none,
            yticks=show_ticks ? :auto : :none,
        )
    end
end

# Updated function to animate 1D plots for multiple datasets
function animate_1D_plots(datasets, titles, t, layout, size_; 
                          save_fig=false, save_name="animation", 
                          const_ylim=true, title_font_size=12, 
                          axis_font_size=10, xlabels=[], ylabels=[], 
                          labels=[], show_labels=true, show_ticks=true,
                          subplot_indices=nothing, show_legend=true, x_vals=nothing,
                          left_margin=10mm, right_margin=10mm, 
                          top_margin=10mm, bottom_margin=10mm)
    
    # Calculate global min and max across all datasets for consistent y-axis scaling
    n_dataset = length(datasets)
    n_snaps = length(t)
    global_min = [minimum(data) for data in datasets]
    global_max = [maximum(data) for data in datasets]

    # Handle default axis labels if not provided
    if isempty(xlabels)
        xlabels = ["x" for _ in 1:n_dataset]
    end
    if isempty(ylabels)
        ylabels = ["y" for _ in 1:n_dataset]
    end
    if isempty(labels)
        labels = ["dataset $(i)" for i in 1:n_dataset]
    end
    
    if subplot_indices === nothing
        subplot_indices = 1:n_dataset
    end

    if x_vals !== nothing 
        if typeof(x_vals) <: Array{<:Int} || typeof(x_vals) <: Array{<:AbstractFloat}
            for i = 1:length(datasets)
                if length(x_vals) != length(datasets[i])
                    error("Length of x_vals must be same length as each dataset - not the same in index ", i )
                end
            end
        else
            if length(x_vals) != length(datasets)
                error("Length of x_vals must match the number of datasets")

            else
                for i = 1:length(datasets)
                    if length(x_vals[i]) != length(datasets[i])
                        error("Length of x_vals must be same length as each dataset - not the same in index ", i )
                    end
                end
            end
        end
    end

    anim = @animate for i = 1:n_snaps
        p = plot(layout=layout, size=size_, 
                 left_margin=left_margin, right_margin=right_margin, 
                 top_margin=top_margin, bottom_margin=bottom_margin)
        
        for j = 1:length(titles)
            time = @sprintf("%.2f", t[i])
            title = titles[j] * " t = $(time)"
            plot!(p[j], title=title)
        end

        for j = 1:n_dataset
            x = x_vals === nothing ? nothing : ( (typeof(x_vals) <: Array{<:Int} || typeof(x_vals) <: Array{<:AbstractFloat}) ? x_vals : x_vals[j])
            if const_ylim
                create_1D_plot!(p[subplot_indices[j]], datasets[j][:,i], x, labels[j], global_min[j], global_max[j], 
                                title_font_size, axis_font_size, xlabels[j], ylabels[j], show_labels, show_ticks, show_legend)
            else
                create_1D_plot!(p[subplot_indices[j]], datasets[j][:,i], x, labels[j], minimum(datasets[j][:,i]), maximum(datasets[j][:,i]), 
                                title_font_size, axis_font_size, xlabels[j], ylabels[j], show_labels, show_ticks, show_legend)
            end
        end
    end

    if save_fig
        mp4(anim, save_name * ".mp4", fps=10)
    else
        mp4(anim, fps=10)
    end
end

#-------- create 1D subplots 
function plot_1D_subplots(datasets, titles, layout, size_; 
    indices = nothing, x_vals = nothing,
    save_fig=false, save_name="1D_plot",
    title_font_size=12, axis_font_size=10, 
    xlabels=[], ylabels=[], labels=[], show_labels=true,
    show_ticks=true,
    subplot_indices=nothing, show_legend=true,
    left_margin=10mm, right_margin=10mm, 
    top_margin=10mm, bottom_margin=10mm)

    # Handle default axis labels if not provided
    if isempty(xlabels)
        xlabels = ["x" for _ in 1:length(datasets)]
    end
    if isempty(ylabels)
        ylabels = ["y" for _ in 1:length(datasets)]
    end
    if isempty(labels)
        labels = ["dataset $(i)" for i in 1:length(datasets)]
    end

    if subplot_indices === nothing
        subplot_indices = 1:length(datasets)
    end


    if x_vals !== nothing 
        if typeof(x_vals) <: Array{<:Int} || typeof(x_vals) <: Array{<:AbstractFloat}
            for i = 1:length(datasets)
                if length(x_vals) != length(datasets[i])
                    error("Length of x_vals must be same length as each dataset - not the same in index ", i )
                end
            end
        else
            if length(x_vals) != length(datasets)
                error("Length of x_vals must match the number of datasets")

            else
                for i = 1:length(datasets)
                    if length(x_vals[i]) != length(datasets[i])
                        error("Length of x_vals must be same length as each dataset - not the same in index ", i )
                    end
                end
            end
        end
    end

    p = plot(layout=layout, size=size_, 
             left_margin=left_margin, right_margin=right_margin, 
             top_margin=top_margin, bottom_margin=bottom_margin)

    for j = 1:length(titles)
        plot!(p[j], title=titles[j])
    end

    for j = 1:length(datasets)


        x = x_vals === nothing ? nothing : ( (typeof(x_vals) <: Array{<:Int} || typeof(x_vals) <: Array{<:AbstractFloat}) ? x_vals : x_vals[j])

        if indices === nothing 
            create_1D_plot!(p[subplot_indices[j]], datasets[j], x, labels[j], 
                            minimum(datasets[j]), maximum(datasets[j]), 
                            title_font_size, axis_font_size, xlabels[j], ylabels[j], show_labels, show_ticks, show_legend)
        else
            create_1D_plot!(p[subplot_indices[j]], datasets[j][:,indices[j]], x, labels[j], 
                            minimum(datasets[j][:,indices[j]]), maximum(datasets[j][:,indices[j]]), 
                            title_font_size, axis_font_size, xlabels[j], ylabels[j], show_labels, show_ticks, show_legend)
        end
    end

    if save_fig
        savefig(p, save_name * ".png")
    end

    display(p)
end
