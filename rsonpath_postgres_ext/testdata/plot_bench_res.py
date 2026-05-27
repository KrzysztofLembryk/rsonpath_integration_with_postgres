import pandas as pd
import matplotlib.pyplot as plt
import io

# tabular data as a raw string

data_hobby = """query_name|method|match_count|avg_ms
$.hobby[*]|jsonpath|3734|16732.731
$.hobby[*]|rsonpath_ext_count|3734|45581.357
$.hobby[*]|jsonpath_gin_filter_only|932|12944.118
$.hobby[*]|rsonpath_gin_filter_only|932|8067.662
$.hobby[*]|jsonpath_gin|3734|13912.647
$.hobby[*]|rsonpath_ext_count_gin|3734|12682.805"""

data_generated_json_89mb = """query_name|method|json_size_mb|avg_ms
$.records[*].name|jsonpath|89.674|8739.181
$.records[*].name|rsonpath_ext_count|89.674|101.302
$.records[*].name|rsonpath_ext_json|89.674|200.556
$.records[*].name|rsonpath_ext_str|89.674|182.776
$.records[*].scores[*]|jsonpath|89.674|356999.834
$.records[*].scores[*]|rsonpath_ext_count|89.674|141.752
$.records[*].scores[*]|rsonpath_ext_json|89.674|478.717
$.records[*].scores[*]|rsonpath_ext_str|89.674|434.614"""

data_generated_json_16mb = """query_name|method|json_size_mb|avg_ms
$.records[*].name|jsonpath|15.520|240.332
$.records[*].name|rsonpath_ext_count|15.520|18.561
$.records[*].name|rsonpath_ext_json|15.520|35.349
$.records[*].name|rsonpath_ext_str|15.520|32.369
$.records[*].scores[*]|jsonpath|15.520|4748.268
$.records[*].scores[*]|rsonpath_ext_count|15.520|25.613
$.records[*].scores[*]|rsonpath_ext_json|15.520|85.870
$.records[*].scores[*]|rsonpath_ext_str|15.520|77.552"""

data_generated_json_8mb = """query_name|method|json_size_mb|avg_ms
$.records[*].name|jsonpath|7.745|59.727
$.records[*].name|rsonpath_ext_count|7.745|9.324
$.records[*].name|rsonpath_ext_json|7.745|15.555
$.records[*].name|rsonpath_ext_str|7.745|14.209
$.records[*].scores[*]|jsonpath|7.745|1148.604
$.records[*].scores[*]|rsonpath_ext_count|7.745|12.374
$.records[*].scores[*]|rsonpath_ext_json|7.745|42.562
$.records[*].scores[*]|rsonpath_ext_str|7.745|38.629"""

data_d3_1_7kb = """query_name|method|match_count|avg_ms
$.authors[*]|jsonpath|18784025|32125.603
$.authors[*]|rsonpath_ext_count|18784025|37811.934
$.authors[*]|rsonpath_ext_str|18784025|46521.180
$.authors[*]|rsonpath_ext_json|18784025|50603.718
$.s2fieldsofstudy[*].category|jsonpath|14247701|33984.821
$.s2fieldsofstudy[*].category|rsonpath_ext_count|14247701|40787.870
$.s2fieldsofstudy[*].category|rsonpath_ext_str|14247701|47908.566
$.s2fieldsofstudy[*].category|rsonpath_ext_json|14247701|48723.853
"""

data_gin = """query_name|method|match_count|avg_ms
$.hobby[*]|jsonpath|3734|15441.249
$.hobby[*]|rsonpath_ext_count|3734|48500.311
$.hobby[*]|jsonpath_gin_filter_only|932|12360.038
$.hobby[*]|rsonpath_gin_filter_only|932|8117.575
$.hobby[*]|jsonpath_gin|3734|13436.985
$.hobby[*]|rsonpath_ext_count_gin|3734|12349.180"""

def create_plots(data, json_size):
    df = pd.read_csv(io.StringIO(data), sep='|')
    df.columns = df.columns.str.strip()
    df['query_name'] = df['query_name'].str.strip()
    df['method'] = df['method'].str.strip()

    plt.style.use('ggplot')
    queries = df['query_name'].unique()

    for query in queries:
        # Filter data for specific query
        subset = df[df['query_name'] == query]
        
        subset = subset.sort_values(by='avg_ms')
        fig, ax = plt.subplots(figsize=(10, 6))
        
        bars = ax.bar(subset['method'], subset['avg_ms'], color=['#348ABD', '#7A68A6', '#A60628', '#467821'][:len(subset)])
        
        ax.set_yscale('log')

        ax.set_title(f'{query} on {json_size} JSON', fontsize=16, fontweight='bold', pad=15)
        ax.set_ylabel('Average Execution Time (ms)', fontsize=12)
        ax.set_xlabel('Method', fontsize=12)
        
        for bar in bars:
            height = bar.get_height()
            # ax.annotate(f'{height:.0f} ms',
            #             xy=(bar.get_x() + bar.get_width() / 2, height),
            #             xytext=(0, 3),  
            #             textcoords="offset points",
            #             ha='center', va='bottom', fontsize=11)
            ax.annotate(f'{height:.0f} ms',
                        xy=(bar.get_x() + bar.get_width() / 2, height),
                        xytext=(0, 5),  # 5 points vertical offset
                        textcoords="offset points",
                        ha='center', va='bottom', fontsize=11)
        
        plt.xticks(rotation=15)
        plt.tight_layout()
        filename_safe = query.replace('$', '').replace('.', '_').replace('[*]', '').replace('[', '_').replace(']', '')
        
        filename = f"plot{filename_safe}_{json_size}.png"
        plt.savefig(filename, dpi=300)
        print(f"Saved plot: {filename}")
        
        plt.close()

def create_combined_plots(datasets, output_filename="combined_plots.png"):
    # Create a 2x2 grid of subplots
    fig, axes = plt.subplots(nrows=len(datasets), ncols=2, figsize=(16, 12))
    axes = axes.flatten()
    
    plt.style.use('ggplot')
    
    # Define consistent colors for the methods
    colors = ['#348ABD', '#7A68A6', '#A60628', '#467821']
    method_patches = {}  # for building a stable legend later

    plot_idx = 0
    for data, json_size in datasets:
        df = pd.read_csv(io.StringIO(data), sep='|')
        df.columns = df.columns.str.strip()
        df['query_name'] = df['query_name'].str.strip()
        df['method'] = df['method'].str.strip()

        queries = df['query_name'].unique()

        for query in queries:
            if plot_idx >= 4:
                break
                
            ax = axes[plot_idx]
            
            # Filter data for specific query, sort to keep bar ordering consistent if needed
            subset = df[df['query_name'] == query].sort_values(by='avg_ms')
            
            # Assign colors dynamically based on their position or enforce specific order
            bars = ax.bar(subset['method'], subset['avg_ms'], color=colors[:len(subset)])
            
            # Save patches for the legend
            for bar, method in zip(bars, subset['method']):
                if method not in method_patches:
                    method_patches[method] = bar

            ax.set_yscale('log')

            ax.set_title(f'{query} on {json_size} JSON', fontsize=14, fontweight='bold', pad=15)
            ax.set_ylabel('Average time (ms) ', fontsize=11)
            
            for bar in bars:
                height = bar.get_height()
                ax.annotate(f'{height:.0f} ms',
                            xy=(bar.get_x() + bar.get_width() / 2, height),
                            xytext=(0, 5),
                            textcoords="offset points",
                            ha='center', va='bottom', fontsize=10)
            
            # Remove the X-axis names/ticks completely
            ax.set_xticks([])
            ax.set_xlabel('')
            
            plot_idx += 1
            
    # Remove any unused axes
    for i in range(plot_idx, len(axes)):
        fig.delaxes(axes[i])

    # Add a unified legend at the top or bottom of the entire figure
    if method_patches:
        labels = list(method_patches.keys())
        handles = list(method_patches.values())
        fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(0.5, 0.98), ncol=len(labels), fontsize=12)
        
        # Adjust layout so title/legend doesn't overlap the subplots
        plt.tight_layout(rect=[0, 0, 1, 0.93])
    else:
        plt.tight_layout()
        
    plt.savefig(output_filename, dpi=300)
    print(f"Saved combined plot: {output_filename}")
    plt.close()

def create_combined_plots_2(datasets, output_filename="combined_plots.png"):
    # First figure out how many plots we actually need
    total_plots = 0
    for data, _ in datasets:
        df = pd.read_csv(io.StringIO(data), sep='|')
        df.columns = df.columns.str.strip()
        df['query_name'] = df['query_name'].str.strip()
        total_plots += len(df['query_name'].unique())
        
    # Calculate grid size (at least 2 columns if more than 1 plot, otherwise 1 column)
    ncols = min(2, total_plots)
    nrows = (total_plots + ncols - 1) // ncols  # ceiling division
    
    # Handle single plot edge case
    if nrows == 0:
        return
        
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(16, 6 * nrows))
    
    # Normalize axes to always be a flat list even if it's 1x1
    if nrows == 1 and ncols == 1:
        axes = [axes]
    else:
        axes = axes.flatten()
    
    plt.style.use('ggplot')
    
    # Map method names strictly to your chosen colors
    color_map = {
        'jsonpath': '#467821',                    # Green
        'rsonpath_ext_json': '#A60628',           # Red
        'rsonpath_ext_str': '#7A68A6',            # Purple
        'rsonpath_ext_count': '#348ABD',          # Blue
        'jsonpath_gin_filter_only': "#84C414",    # Lighter green
        'rsonpath_gin_filter_only': "#303D9B",    # Lighter red/orange
        'jsonpath_gin': "#00D131",                # Medium green
        'rsonpath_ext_count_gin': "#306C90"       # Lighter purple
    }
    method_patches = {}

    plot_idx = 0
    for data, json_size in datasets:
        df = pd.read_csv(io.StringIO(data), sep='|')
        df.columns = df.columns.str.strip()
        df['query_name'] = df['query_name'].str.strip()
        df['method'] = df['method'].str.strip()

        queries = df['query_name'].unique()

        for query in queries:
            if plot_idx >= len(axes):
                break
                
            ax = axes[plot_idx]
            subset = df[df['query_name'] == query].sort_values(by='avg_ms')
            
            # Map colors based on the dataframe column method values. 
            # Fallback to grey if a new method appears that isn't mapped.
            bar_colors = [color_map.get(method, '#888888') for method in subset['method']]
            
            bars = ax.bar(subset['method'], subset['avg_ms'], color=bar_colors)
            
            for bar, method in zip(bars, subset['method']):
                if method not in method_patches:
                    method_patches[method] = bar

            # We use a linear scale if you want, but you mentioned log scale earlier.
            ax.set_yscale('log')

            ax.set_title(f'{query}', fontsize=14, fontweight='bold', pad=15)
            ax.set_ylabel('Average time (ms)', fontsize=11)
            
            for bar in bars:
                height = bar.get_height()
                ax.annotate(f'{height:.0f} ms',
                            xy=(bar.get_x() + bar.get_width() / 2, height),
                            xytext=(0, 5),
                            textcoords="offset points",
                            ha='center', va='bottom', fontsize=10)
            
            ax.set_xticks([])
            ax.set_xlabel('')
            
            plot_idx += 1
            
    for i in range(plot_idx, len(axes)):
        fig.delaxes(axes[i])

    if method_patches:
        labels = list(method_patches.keys())
        handles = list(method_patches.values())
        
        # Determine the top margin offset depending on the grid layout height
        bbox_anch = 0.98 if nrows <= 2 else 0.95 
        
        fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(0.5, bbox_anch), ncol=len(labels), fontsize=12)
        plt.tight_layout(rect=[0, 0, 1, bbox_anch - 0.05])
    else:
        plt.tight_layout()
        
    plt.savefig(output_filename, dpi=300)
    print(f"Saved combined plot: {output_filename}")
    plt.close()


if __name__ == "__main__":
    # create_plots(data=data_generated_json_89mb, json_size="90MB")

    # datasets_to_plot = [
    #     (data_generated_json_89mb, "90MB"),
    #     (data_generated_json_8mb, "8MB")
    # ]
    
    # create_combined_plots(datasets_to_plot, output_filename="plot_combined_90mb_8mb.png")

    # create_combined_plots_2([(data_d3_1_7kb, "2KB")], output_filename="plot_combined_d3_2KB.png")

    create_combined_plots_2([(data_gin, "1MB")], output_filename="plot_combined_gin.png")

