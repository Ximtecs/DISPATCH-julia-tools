using Plots
using Printf
using Measures



# Create a function to generate the heatmap plot
function create_heatmap_plot(data, title, min_val, max_val, title_font_size, cmap_font_size, axis_font_size, xlabel, ylabel, show_labels, show_colorbar, show_ticks)
    heatmap(
        data, 
        color=:viridis, 
        title=title, 
        clim=(min_val, max_val), 
        xlabel=show_labels ? xlabel : "", 
        ylabel=show_labels ? ylabel : "", 
        titlefontsize=title_font_size, 
        guidefontsize=axis_font_size,
        tickfontsize=cmap_font_size,
        colorbar=show_colorbar,
        xticks=show_ticks ? :auto : :none,
        yticks=show_ticks ? :auto : :none,
    )
end

# Updated function to animate heatmap plots for multiple datasets
function animate_heatmap_plots(datasets, titles, t, layout, size_; 
                               save_fig=false, save_name="animation", 
                               const_cmap=true, title_font_size=12, 
                               cmap_font_size=10, axis_font_size=10, 
                               xlabels=[], ylabels=[], show_labels=true,
                               show_colorbar=true, show_ticks=true,
                               left_margin=10mm, right_margin=10mm, 
                               top_margin=10mm, bottom_margin=10mm)
    
    # Calculate global min and max across all datasets for consistent color scaling
    n_dataset = length(datasets)
    global_min = [minimum(data) for data in datasets]
    global_max = [maximum(data) for data in datasets]

    # Handle default axis labels if not provided
    if isempty(xlabels)
        xlabels = ["x" for _ in 1:n_dataset]
    end
    if isempty(ylabels)
        ylabels = ["y" for _ in 1:n_dataset]
    end
    
    anim = @animate for i = 1:size(datasets[1], 3)
        plots = []
        for j = 1:n_dataset
            time = @sprintf("%.2f", t[i])

            if const_cmap
                push!(plots, create_heatmap_plot(datasets[j][:,:,i]', 
                                                 titles[j] * " t = $(time)", 
                                                 global_min[j], global_max[j], 
                                                 title_font_size, cmap_font_size, 
                                                 axis_font_size, xlabels[j], ylabels[j], show_labels, show_colorbar, show_ticks))
            else
                push!(plots, create_heatmap_plot(datasets[j][:,:,i]', 
                                                 titles[j] * " t = $(time)", 
                                                 minimum(datasets[j][:,:,i]), 
                                                 maximum(datasets[j][:,:,i]), 
                                                 title_font_size, cmap_font_size, 
                                                 axis_font_size, xlabels[j], ylabels[j], show_labels, show_colorbar, show_ticks))
            end
        end

        plot(plots..., layout=layout, size=size_, 
             left_margin=left_margin, right_margin=right_margin, 
             top_margin=top_margin, bottom_margin=bottom_margin)
    end

    if save_fig
        mp4(anim, save_name * ".mp4", fps=10)
    else
        mp4(anim, fps=10)
    end
end

#-------- create heatmap subplots 
function plot_heatmaps(datasets, titles, indices, layout, size_; 
    save_fig=false, save_name="heatmap",
    title_font_size=12, cmap_font_size=10, axis_font_size=10, 
    xlabels=[], ylabels=[], show_labels=true,
    show_colorbar=true, show_ticks=true,
    left_margin=10mm, right_margin=10mm, 
    top_margin=10mm, bottom_margin=10mm)

    # Handle default axis labels if not provided
    if isempty(xlabels)
        xlabels = ["x" for _ in 1:length(datasets)]
    end
    if isempty(ylabels)
        ylabels = ["y" for _ in 1:length(datasets)]
    end

    plots = []
    for j = 1:length(datasets)
        push!(plots, create_heatmap_plot(datasets[j][:,:,indices[j]]', 
                        titles[j], 
                        minimum(datasets[j][:,:,indices[j]]), 
                        maximum(datasets[j][:,:,indices[j]]), 
                        title_font_size, cmap_font_size, 
                        axis_font_size, xlabels[j], ylabels[j], show_labels, show_colorbar, show_ticks))
    end

    p = plot(plots..., layout=layout, size=size_, 
            left_margin=left_margin, right_margin=right_margin, 
            top_margin=top_margin, bottom_margin=bottom_margin)

    if save_fig
        savefig(p, save_name * ".png")
    end

end