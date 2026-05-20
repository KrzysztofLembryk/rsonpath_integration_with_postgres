import pandas as pd
import matplotlib.pyplot as plt
import io

# tabular data as a raw string
data_d3 = """query_name|method|match_count|avg_ms|min_ms|max_ms
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

data_generated_json_1mb = """query_name|method|match_count|avg_ms
$.address1.city1|jsonpath|10000|16681.997
$.address1.city1|rsonpath_ext_json|10000|43762.908
$.address1.city1|rsonpath_ext_str|10000|43764.669
$.address1.city1|rsonpath_ext_count|10000|44545.557
$.email1|jsonpath|10000|16913.768
$.email1|rsonpath_ext_json|10000|43725.370
$.email1|rsonpath_ext_count|10000|43934.154
$.email1|rsonpath_ext_str|10000|43998.674
$.hobby[*]|jsonpath|3734|14942.930
$.hobby[*]|rsonpath_ext_str|3734|45473.538
$.hobby[*]|rsonpath_ext_count|3734|45521.427
$.hobby[*]|rsonpath_ext_json|3734|47586.063
$.nested1.nested2.countries[*]|rsonpath_ext_count|300000000|50966.633
$.nested1.nested2.countries[*]|rsonpath_ext_str|300000000|96533.801
$.nested1.nested2.countries[*]|rsonpath_ext_json|300000000|102454.666
$.nested1.nested2.countries[*]|jsonpath|300000000|421832.793"""


df1 = pd.read_csv(io.StringIO(data_d3), sep='|')
df2 = pd.read_csv(io.StringIO(data_generated_json_1mb), sep='|')
df = pd.concat([df1, df2], ignore_index=True)

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
    
    ax.set_title(f'Performance Comparison: {query}', fontsize=16, fontweight='bold', pad=15)
    ax.set_ylabel('Average Execution Time (ms)', fontsize=12)
    ax.set_xlabel('Method', fontsize=12)
    
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height:.0f} ms',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),  
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=11)
    
    plt.xticks(rotation=15)
    plt.tight_layout()
    filename_safe = query.replace('$', '').replace('.', '_').replace('[*]', '').replace('[', '_').replace(']', '')
    
    filename = f"plot{filename_safe}.png"
    plt.savefig(filename, dpi=300)
    print(f"Saved plot: {filename}")
    
    plt.close()