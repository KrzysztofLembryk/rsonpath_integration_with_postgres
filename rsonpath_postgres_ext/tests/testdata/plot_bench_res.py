import pandas as pd
import matplotlib.pyplot as plt
import io

# 1. Provide the tabular data as a raw string
data = """query_name|method|match_count|avg_ms|min_ms|max_ms
$.authors[*].name|jsonpath|18784025|35042.522|35042.522|35042.522
$.authors[*].name|rsonpath_ext_count|18784025|40516.415|40516.415|40516.415
$.authors[*].name|rsonpath_ext_str|18784025|49450.305|49450.305|49450.305
$.authors[*].name|rsonpath_ext_json|18784025|51760.182|51760.182|51760.182
$.s2fieldsofstudy[*].category|jsonpath|14247701|31203.528|31203.528|31203.528
$.s2fieldsofstudy[*].category|rsonpath_ext_count|14247701|41948.420|41948.420|41948.420
$.s2fieldsofstudy[*].category|rsonpath_ext_str|14247701|49283.692|49283.692|49283.692
$.s2fieldsofstudy[*].category|rsonpath_ext_json|14247701|51804.230|51804.230|51804.230
$.externalids.DOI|jsonpath|5944139|29303.842|29303.842|29303.842
$.externalids.DOI|rsonpath_ext_count|5944139|40832.494|40832.494|40832.494
$.externalids.DOI|rsonpath_ext_str|5944139|45273.103|45273.103|45273.103
$.externalids.DOI|rsonpath_ext_json|5944139|46114.566|46114.566|46114.566
$.title|jsonpath|5944139|29062.295|29062.295|29062.295
$.title|rsonpath_ext_count|5944139|39318.640|39318.640|39318.640
$.title|rsonpath_ext_str|5944139|44603.521|44603.521|44603.521
$.title|rsonpath_ext_json|5944139|46042.591|46042.591|46042.591
$.year|jsonpath|5944139|29047.450|29047.450|29047.450
$.year|rsonpath_ext_count|5944139|39636.226|39636.226|39636.226
$.year|rsonpath_ext_str|5944139|44962.596|44962.596|44962.596
$.year|rsonpath_ext_json|5944139|45752.006|45752.006|45752.006"""

# 2. Load into into a Pandas DataFrame
df = pd.read_csv(io.StringIO(data), sep='|')
# Strip any stray spaces from column names and string columns
df.columns = df.columns.str.strip()
df['query_name'] = df['query_name'].str.strip()
df['method'] = df['method'].str.strip()

# Set an aesthetic style
plt.style.use('ggplot')

# 3. Get unique query names
queries = df['query_name'].unique()

for query in queries:
    # Filter data for this specific query
    subset = df[df['query_name'] == query]
    
    # Sort so the bars are in a consistent order
    subset = subset.sort_values(by='avg_ms')
    
    # Create the plot
    fig, ax = plt.subplots(figsize=(10, 6))
    
    bars = ax.bar(subset['method'], subset['avg_ms'], color=['#348ABD', '#7A68A6', '#A60628', '#467821'][:len(subset)])
    
    ax.set_title(f'Performance Comparison: {query}', fontsize=16, fontweight='bold', pad=15)
    ax.set_ylabel('Average Execution Time (ms)', fontsize=12)
    ax.set_xlabel('Method', fontsize=12)
    
    # Add exact time labels above the bars
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height:,.0f} ms',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),  
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=11)
    
    # Adjust layout and save string matching the query name replacing special chars
    plt.xticks(rotation=15)
    plt.tight_layout()
    filename_safe = query.replace('$', 'root').replace('.', '_').replace('[*]', '_wildcard').replace('[', '_').replace(']', '')
    
    filename = f"plot_{filename_safe}.png"
    plt.savefig(filename, dpi=300)
    print(f"Saved plot: {filename}")
    
    # If running interactively you can also show it:
    # plt.show()
    plt.close()