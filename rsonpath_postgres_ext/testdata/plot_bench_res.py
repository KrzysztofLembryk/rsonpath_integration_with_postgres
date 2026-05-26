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

# data_generated_json_1mb = """query_name|method|match_count|avg_ms
# $.address1.city1|jsonpath|10000|16681.997
# $.address1.city1|rsonpath_ext_json|10000|43762.908
# $.address1.city1|rsonpath_ext_str|10000|43764.669
# $.address1.city1|rsonpath_ext_count|10000|44545.557
# $.email1|jsonpath|10000|16913.768
# $.email1|rsonpath_ext_json|10000|43725.370
# $.email1|rsonpath_ext_count|10000|43934.154
# $.email1|rsonpath_ext_str|10000|43998.674
# $.hobby[*]|jsonpath|3734|14942.930
# $.hobby[*]|rsonpath_ext_str|3734|45473.538
# $.hobby[*]|rsonpath_ext_count|3734|45521.427
# $.hobby[*]|rsonpath_ext_json|3734|47586.063
# $.nested1.nested2.countries[*]|rsonpath_ext_count|300000000|50966.633
# $.nested1.nested2.countries[*]|rsonpath_ext_str|300000000|96533.801
# $.nested1.nested2.countries[*]|rsonpath_ext_json|300000000|102454.666
# $.nested1.nested2.countries[*]|jsonpath|300000000|421832.793"""

data_generated_json_1mb = """query_name|method|match_count|avg_ms
$.address1.city1|jsonpath_with_cast|10000|12079.653
$.address1.city1|jsonpath_no_cast|10000|12153.546
$.address1.city1|rsonpath_ext_count|10000|43522.942
$.address1.city1|rsonpath_ext_str|10000|43632.577
$.address1.city1|rsonpath_ext_json|10000|43664.766
$.cities[*]|rsonpath_ext_count|300000000|45646.715
$.cities[*]|rsonpath_ext_str|300000000|84958.857
$.cities[*]|rsonpath_ext_json|300000000|97826.613
$.cities[*]|jsonpath_with_cast|300000000|391020.057
$.cities[*]|jsonpath_no_cast|300000000|402916.620
$.email1|jsonpath_with_cast|10000|12079.480
$.email1|jsonpath_no_cast|10000|12101.644
$.email1|rsonpath_ext_count|10000|43475.215
$.email1|rsonpath_ext_str|10000|43637.784
$.email1|rsonpath_ext_json|10000|43699.923
$.hobby[*]|jsonpath_with_cast|3734|12068.948
$.hobby[*]|jsonpath_no_cast|3734|12141.969
$.hobby[*]|rsonpath_ext_count|3734|43563.827
$.hobby[*]|rsonpath_ext_json|3734|43637.019
$.hobby[*]|rsonpath_ext_str|3734|43714.196
$.nested1.nested2.countries[*]|rsonpath_ext_count|300000000|45408.272
$.nested1.nested2.countries[*]|rsonpath_ext_str|300000000|87710.235
$.nested1.nested2.countries[*]|rsonpath_ext_json|300000000|101249.476
$.nested1.nested2.countries[*]|jsonpath_no_cast|300000000|390982.474
$.nested1.nested2.countries[*]|jsonpath_with_cast|300000000|391686.303
$.tags1[*]|rsonpath_ext_count|150000000|44424.402
$.tags1[*]|rsonpath_ext_str|150000000|64592.075
$.tags1[*]|rsonpath_ext_json|150000000|70752.957
$.tags1[*]|jsonpath_with_cast|150000000|106523.196
$.tags1[*]|jsonpath_no_cast|150000000|106855.967"""


data_gin = """query_name|method|avg_ms
$.authors[*]|jsonpath|31017.942
$.authors[*]|rsonpath_ext_count|38463.632
$.authors[*]|jsonpath_gin_filter_only|29912.751
$.authors[*]|rsonpath_gin_filter_only|122774.589
$.authors[*]|jsonpath_gin|43363.805
$.authors[*]|rsonpath_ext_count_gin|182492.981
$.authors[*].name|jsonpath|32042.751
$.authors[*].name|rsonpath_ext_count|40757.772
$.authors[*].name|jsonpath_gin_filter_only|28578.241
$.authors[*].name|rsonpath_gin_filter_only|123370.361
$.authors[*].name|jsonpath_gin|44683.012
$.authors[*].name|rsonpath_ext_count_gin|182256.538
$.externalids.DOI|jsonpath|30297.759
$.externalids.DOI|rsonpath_ext_count|39582.676
$.externalids.DOI|jsonpath_gin_filter_only|28701.365
$.externalids.DOI|rsonpath_gin_filter_only|121153.205
$.externalids.DOI|rsonpath_ext_count_gin|179755.093
$.externalids.DOI|jsonpath_no_cast_gin|42322.891
$.s2fieldsofstudy[*].category|jsonpath_no_cast|32686.583
$.s2fieldsofstudy[*].category|rsonpath_ext_count|41525.881
$.s2fieldsofstudy[*].category|jsonpath_gin_filter_only|29971.203
$.s2fieldsofstudy[*].category|rsonpath_gin_filter_only|131670.548
$.s2fieldsofstudy[*].category|jsonpath_no_cast_gin|43203.366
$.s2fieldsofstudy[*].category|rsonpath_ext_count_gin|187935.905
$.title|jsonpath_no_cast|30971.067
$.title|rsonpath_ext_count|37639.887
$.title|jsonpath_gin_filter_only|28962.579
$.title|rsonpath_gin_filter_only|124687.104
$.title|jsonpath_no_cast_gin|41993.778
$.title|rsonpath_ext_count_gin|180043.974
$.year|jsonpath_no_cast|31055.175
$.year|rsonpath_ext_count|39061.697
$.year|jsonpath_gin_filter_only|36552.025
$.year|rsonpath_gin_filter_only|123236.915
$.year|jsonpath_no_cast_gin|50861.641
$.year|rsonpath_ext_count_gin|177597.530"""

data_hobby = """query_name|method|match_count|avg_ms
$.hobby[*]|jsonpath|3734|16732.731
$.hobby[*]|rsonpath_ext_count|3734|45581.357
$.hobby[*]|jsonpath_gin_filter_only|932|12944.118
$.hobby[*]|rsonpath_gin_filter_only|932|8067.662
$.hobby[*]|jsonpath_gin|3734|13912.647
$.hobby[*]|rsonpath_ext_count_gin|3734|12682.805"""


def create_plots(data):
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


if __name__ == "__main__":
    # create_plots(data=data_gin)
    create_plots(data=data_generated_json_1mb)

