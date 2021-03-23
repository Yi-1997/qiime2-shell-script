#!/bin/bash
# program:
# This program is a procedure for qiime2
# History:
# 2020/12/22  yi  first release
#启动qiime2
qiime2(){
  cd /usr/local/miniconda3/bin
  . ./activate qiime2-2021.2
  export TMPDIR='/home/ncbi'
  export JOBLIB_TEMP_FOLDER='/home/ncbi'#此命令为指定缓存目录，如果遇到内存报错，请重输该命令
  env | grep 'TMP\|TEMP' #此命令为确定缓存目录，请确定输出结果显示为TMPDIR=/home/ncbi、JOBLIB_TEMP_FOLDER=/home/ncbi，如果不是请重输上一步命令
  read -p "please input your work path: " work_path
  cd ${work_path}
}

#单端数据导入
single_data_import(){
    time qiime tools import \
      --type "SampleData[SequencesWithQuality]" \
      --input-format SingleEndFastqManifestPhred33V2 \
      --input-path ./$1 \
      --output-path ./$2
}
#双端数据导入
paired_data_import(){
    time qiime tools import \
      --type "SampleData[PairedEndSequencesWithQuality]" \
      --input-format PairedEndFastqManifestPhred33V2 \
      --input-path ./$1 \
      --output-path ./$2
}
#导入数据可视化
import_visualization(){
        time qiime demux summarize \
    --i-data ./$1.qza \
    --o-visualization ./$1.qzv
}

#数据导入
data_import(){
    case ${2} in
    "1")
        #单端数据导入
    single_data_import ${1}_manifest.tsv ${1}_single-end-demux_seqs.qza
        #单端数据可视化
    import_visualization ${1}_single-end-demux_seqs
    ;;
    "2")
        #双端数据导入
    paired_data_import ${1}_manifest.tsv ${1}_paired-end-demux_seqs.qza
        #双端数据可视化
    import_visualization ${1}_paired-end-demux_seqs
    ;;
    esac
}

#单端引物切除
cutadapt_single_primer(){
    read -p "now runing cutadapt, please input front-forward-primer: " primer
    qiime cutadapt trim-single \
      --i-demultiplexed-sequences $1 \
      --p-cores 32  \
      --p-front ${primer} \
      --o-trimmed-sequences $2 \
      --verbose 
}

#双端引物切除
cutadapt_paired_primer(){
    read -p "now runing cutadapt, please input front-forward-primer: " forward_primer
    read -p "now runing cutadapt, please input front-reverse-primer: " reverse_primer
    time qiime cutadapt trim-paired \
      --i-demultiplexed-sequences $1 \
      --p-front-f ${forward_primer} \
      --p-front-r ${reverse_primer} \
      --o-trimmed-sequences $2 \
      --p-discard-untrimmed \
      --verbose \
      &> primer_trimming.log
}

#序列双端合并
vsearch_join_pairs(){
time qiime vsearch join-pairs \
  --i-demultiplexed-seqs $1 \
  --p-truncqual 20 \
  --p-minovlen 10 \
  --p-maxdiffs 3 \
  --o-joined-sequences $2
}

#获得序列双端合并数据的可视化结果
demux_summarize(){
time qiime demux summarize \
  --i-data $1.qza \
  --o-visualization $1.qzv
}

#dada2降噪
dada2_denoise(){
case ${2} in
    "1")
    dada2_denoise_single ${1}_single-end-demux_seqs.qza ${1}_rep-seqs-dada2.qza ${1}_table-dada2.qza ${1}_stats-dada2.qza
    ;;
    "2")
    dada2_denoise_paired ${1}_paired-end-demux_seqs.qza ${1}_rep-seqs-dada2.qza ${1}_table-dada2.qza ${1}_stats-dada2.qza
    ;;
esac
}

#deblur降噪
deblur_denoise(){
  read -p "now runing deblur, please input trim length: " trim_length
  time qiime deblur denoise-16S \
    --i-demultiplexed-seqs $1 \
    --p-trim-length ${trim_length} \
    --p-sample-stats \
    --p-jobs-to-start 20 \
    --o-representative-sequences $2 \
    --o-table $3.qza \
    --o-stats $4.qza
  
  #将此步产生的统计过程可视化
  time qiime deblur visualize-stats\
    --i-deblur-stats $4.qza \
    --o-visualization $4.qzv

  #可视化deblur特征表
  time qiime feature-table summarize \
    --i-table $3.qza \
    --o-visualization $3.qzv \
    --m-sample-metadata-file $5
}

#单端dada2降噪
dada2_denoise_single(){
    read -p "now runing dada2_denoise_single, trim-left： " trim_left
    read -p "now runing dada2_denoise_single, trunc-len： " trunc_len
    time qiime dada2 denoise-single \
      --i-demultiplexed-seqs $1 \
      --p-trim-left ${trim_left} \
      --p-trunc-len ${trunc_len} \
      --o-representative-sequences $2 \
      --o-table $3 \
      --o-denoising-stats $4
}

#双端dada2降噪
dada2_denoise_paired(){
    read -p "now runing dada2_denoise_paired, trim-left-f: " trim_left_f
    read -p "now runing dada2_denoise_paired, trim-left-r: " trim_left_r
    read -p "now runing dada2_denoise_paired, trunc-len-f: " trunc_len_f
    read -p "now runing dada2_denoise_paired, trunc-len-r: " trunc_len_r
    time qiime dada2 denoise-paired \
      --i-demultiplexed-seqs $1 \
      --p-trim-left-f ${trim_left_f} \
      --p-trim-left-r ${trim_left_r} \
      --p-trunc-len-f ${trunc_len_f} \
      --p-trunc-len-r ${trunc_len_r} \
      --o-table $3 \
      --o-representative-sequences $2 \
      --o-denoising-stats $4
}

#特征表和代表序列可视化
fea_and_rep_summarize(){
    #特征表汇总
    time qiime feature-table summarize \
      --i-table $1.qza \
      --o-visualization $1.qzv \
      --m-sample-metadata-file $2

    #代表序列汇总
    time qiime feature-table tabulate-seqs \
      --i-data $3.qza \
      --o-visualization $3.qzv

    #特征表统计可视化
    time qiime metadata tabulate \
      --m-input-file $4.qza \
      --o-visualization $4.qzv
}

#进化树分析
phylogeny_tree(){
    time qiime phylogeny align-to-tree-mafft-fasttree \
      --i-sequences $1 \
      --o-alignment $2 \
      --o-masked-alignment $3 \
      --o-tree $4 \
      --o-rooted-tree $5
}
#样品稀释（抽平）
feature_table_rarefy(){
  read -p "now runing feature_table_rarefy, p-sampling-depth(most base on alpha_rarefaction_visualization): " p_samping_depth
    time qiime feature-table rarefy \
      --i-table $1\
      --p-sampling-depth ${p_samping_depth} \
      --o-rarefied-table $2_rarefied.qza
}
  
#稀释曲线（最大深度一般基于中位数）
alpha_rarefaction(){
    read -p "now runing alpha_rarefaction, p-max-depth(most base on sample median frequency): " p_max_depth
    time qiime diversity alpha-rarefaction \
      --i-table $1 \
      --i-phylogeny $2 \
      --p-max-depth ${p_max_depth} \
      --m-metadata-file $3 \
      --o-visualization $4
}

#计算核心多样性（样品深度数据量大选最小，数据量小排除掉第一第二的极端值）
diversity_core(){
    read -p "now runing diversity_core, p-sampling-depth(exclude extreme, most base on sample Minimum frequency: " p_sampling_depth
    time qiime diversity core-metrics-phylogenetic \
      --i-phylogeny $1 \
      --i-table $2 \
      --p-sampling-depth ${p_sampling_depth} \
      --m-metadata-file $3 \
      --output-dir $4
}

#计算Non-phylogenetic alpha diversity指标,例如：ACE,chao1等指标
alpha_diversity(){
  time qiime diversity alpha \
    --i-table $1 \
    --p-metric $2 \
    --o-alpha-diversity $3
}

#Alpha多样性组间显著性分析和可视化
alpha_group_significance(){
    time qiime diversity alpha-group-significance \
      --i-alpha-diversity $1 \
      --m-metadata-file $2 \
      --o-visualization $3
    }

#组别显著性检验
beta_group_significance(){
    read -p "now runing beta_group_significance, m-metadata-column: " m_metadata_column
    time qiime diversity beta-group-significance \
      --i-distance-matrix $1 \
      --m-metadata-file $2 \
      --m-metadata-column ${m_metadata_column} \
      --o-visualization ${3}_core-metrics-results/unweighted-unifrac-body-${m_metadata_column}-significance.qzv \
      --p-pairwise
}

#物种注释
feature_classifier(){
    read -p "now runing feature_classifier, please enter data path(press key \"enter\" choose default:silva-138-99-nb-classifier): " data
    time qiime feature-classifier classify-sklearn \
      --i-classifier ${data:=/home/qiime2/silva-138-99-nb-classifier.qza} \
      --i-reads $1 \
      --o-classification $2
}

#交互式条形图
taxa_barplot(){
    time qiime taxa barplot \
      --i-table $1 \
      --i-taxonomy $2 \
      --m-metadata-file $3 \
      --o-visualization $4   
}

#保留门注释，去除叶绿体和线粒体
filter_table(){
    read -p "now runing filter_table, choose include(press key \"enter\" choose default:p__): " include
    read -p "now runing filter_table, choose exclude(press key \"enter\" choose default:mitochondria,chloroplast): " exclude 
    time qiime taxa filter-table \
      --i-table $1 \
      --i-taxonomy $2 \
      --p-include ${include:=p__} \
      --p-exclude ${exclude:=mitochondria,chloroplast} \
      --o-filtered-table $3
}

#导出特征表和进化树，生成biom和进化树文件
tools_export(){
    time qiime tools export \
      --input-path $1 \
      --output-path $2
    time qiime tools export \
      --input-path $3 \
      --output-path $4
}

#机器学习分类
sample_classifier(){
    read -p "now runing sample_classifier, choose metadata-column(press key \"enter\" choose default:host_phenotype): " metadata_column
    read -p "now runing sample_classifier, choose random-state(press key \"enter\" choose default:666): " random_state
    read -p "now runing sample_classifier, choose estimator(press key \"enter\" choose default:RandomForestClassifier): " estimator
    read -p "now runing sample_classifier, choose n_estimators(press key \"enter\" choose default:1000): " n_estimators
    time qiime sample-classifier classify-samples \
      --i-table ./$1 \
      --m-metadata-file ./$2 \
      --m-metadata-column ${metadata_column:=host_phenotype}\
      --p-optimize-feature-selection \
      --p-parameter-tuning \
      --p-random-state ${random_state:=666} \
      --p-estimator ${estimator:=RandomForestClassifier} \
      --p-n-estimators ${n_estimators:=1000} \
      --output-dir $3
}

#重要度可视化
importance(){
    time qiime metadata tabulate \
      --m-input-file $1 \
      --o-visualization $2
}

read -p "choose whole process or a single program, please enter 1/2 to choose: " choose
if [ "${choose}" == "1" ]; then
    #qiime2全流程
    
    #启动qiime2
    qiime2
    read -p "please enter project name: " project
    read -p "please enter data format, 1 stands for single, 2 stands for Paired： " Data_format
    #数据导入
    data_import ${project} ${Data_format}
    #dada2降噪
    dada2_denoise ${project} ${Data_format}
    #特征表和代表序列汇总
    fea_and_rep_summarize ${project}_table-dada2 ${project}_metadata.tsv ${project}_rep-seqs-dada2 ${project}_stats-dada2 
    #构建系统发育树
    phylogeny_tree ${project}_rep-seqs-dada2.qza ${project}_aligned-rep-seqs.qza ${project}_masked-aligned-rep-seqs.qza ${project}_unrooted-tree.qza ${project}_rooted-tree.qza
    #物种注释
    feature_classifier ${project}_rep-seqs-dada2.qza ${project}_taxonomy.qza
    #交互式条形图
    taxa_barplot ${project}_table-dada2.qza ${project}_taxonomy.qza ${project}_metadata.tsv ${project}_taxa-bar-plots.qzv
    #保留门注释，去除叶绿体和线粒体
    mv ${project}_table-dada2.qza ${project}_unfilter_table-dada2.qza
    filter_table ${project}_unfilter_table-dada2.qza ${project}_taxonomy.qza ${project}_table-dada2.qza
    #稀释曲线
    alpha_rarefaction ${project}_table-dada2.qza ${project}_rooted-tree.qza ${project}_metadata.tsv ${project}_alpha-rarefaction.qzv
    #计算核心多样性
    diversity_core ${project}_rooted-tree.qza ${project}_table-dada2.qza ${project}_metadata.tsv ${project}_core-metrics-results
    #计算alpha多样性ace指标
    alpha_diversity ${project}_table-dada2.qza ace ${project}_core-metrics-results/ace_vector.qza
    #计算alpha多样性chao1指标
    alpha_diversity ${project}_table-dada2.qza chao1 ${project}_core-metrics-results/chao1_vector.qza
    #计算alpha多样性simpson指标
    alpha_diversity ${project}_table-dada2.qza simpson ${project}_core-metrics-results/simpson_vector.qza
    #Alpha多样性faith_pd指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/faith_pd_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/faith-pd-group-significance.qzv
    #Alpha多样性evenness指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/evenness_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/evenness-group-significance.qzv
    #Alpha多样性ace指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/ace_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/ace-group-significance.qzv
    #Alpha多样性chao1指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/chao1_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/chao1-group-significance.qzv
    #Alpha多样性simpson指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/simpson_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/simpson-group-significance.qzv
    #Alpha多样性shannon指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/shannon_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/shannon-group-significance.qzv
    #Alpha多样性observed_features指标组间显著性分析和可视化
    alpha_group_significance ${project}_core-metrics-results/observed_features_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/observed_features-group-significance.qzv
    #beta多样性unweighted_unifrac_distance_matrix数据组别显著性检验
    beta_group_significance ${project}_core-metrics-results/unweighted_unifrac_distance_matrix.qza ${project}_metadata.tsv ${project}
    #导出特征表和进化树，生成biom和进化树文件
    tools_export ${project}_table.qza exported_${project} ${project}_unrooted-tree.qza exported_${project}_tree.qza
    #随机森林分类
    sample_classifier ${project}_table-dada2.qza ${project}_metadata.tsv ${project}_sample-classifier-results
    #重要度可视化
    importance ${project}_sample-classifier-results/feature_importance.qza ${project}_sample-classifier-results/feature_importance.qzv
    echo "finish!"
else
#单项流程选择
    #启动qiime2
    qiime2
    while [ "${yn}" != "n" -a "${yn}" != "N" ] 
    do
        read -p "please choose procedure:
                    1:data import
                    2:dada2_denoise
                    3:fea_and_rep_summarize
                    4:phylogeny_tree
                    5:alpha-rarefaction
                    6:diversity_core
                    7:alpha-group-significance
                    8:beta-group-significance
                    9:feature-classifier
                    10:taxa_barplot
                    11:filter_table
                    12:tools_export
                    13:sample-classifier
                    14:importance visualization
                    15:cutadapt_paired_primer
                    16:cutadapt_single_primer
                    17:vsearch_join_pairs
                    18:deblur_denoise
                    19:feature_table_rarefy
                    option: " procedure
        read -p "please enter project name: " project
        case ${procedure} in
            "1")
            read -p "please enter data format, 1 stands for single, 2 stands for Paired： " Data_format
            data_import ${project} ${Data_format}
            ;;
            "2")
            read -p "please enter data format, 1 stands for single, 2 stands for Paired： " Data_format
            dada2_denoise ${project} ${Data_format}
            ;;
            "3")
            fea_and_rep_summarize ${project}_table-dada2 ${project}_metadata.tsv ${project}_rep-seqs-dada2 ${project}_stats-dada2
            ;;
            "4")
            phylogeny_tree ${project}_rep-seqs-dada2.qza ${project}_aligned-rep-seqs.qza ${project}_masked-aligned-rep-seqs.qza ${project}_unrooted-tree.qza ${project}_rooted-tree.qza
            ;;
            "5")
            alpha_rarefaction ${project}_table-dada2.qza ${project}_rooted-tree.qza ${project}_metadata.tsv ${project}_alpha-rarefaction.qzv
            ;;
            "6")
            diversity_core ${project}_rooted-tree.qza ${project}_table-dada2.qza ${project}_metadata.tsv ${project}_core-metrics-results
            #计算alpha多样性ace指标
            alpha_diversity ${project}_table-dada2.qza ace ${project}_core-metrics-results/ace_vector.qza
            #计算alpha多样性chao1指标
            alpha_diversity ${project}_table-dada2.qza chao1 ${project}_core-metrics-results/chao1_vector.qza
            #计算alpha多样性simpson指标
            alpha_diversity ${project}_table-dada2.qza simpson ${project}_core-metrics-results/simpson_vector.qza
            ;;
            "7")
            #Alpha多样性faith_pd指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/faith_pd_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/faith-pd-group-significance.qzv
            #Alpha多样性evenness指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/evenness_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/evenness-group-significance.qzv
            #Alpha多样性ace指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/ace_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/ace-group-significance.qzv
            #Alpha多样性chao1指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/chao1_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/chao1-group-significance.qzv
            #Alpha多样性simpson指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/simpson_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/simpson-group-significance.qzv
            #Alpha多样性shannon指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/shannon_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/shannon-group-significance.qzv
            #Alpha多样性observed_features指标组间显著性分析和可视化
            alpha_group_significance ${project}_core-metrics-results/observed_features_vector.qza ${project}_metadata.tsv ${project}_core-metrics-results/observed_features-group-significance.qzv
            ;;
            "8")
            beta_group_significance ${project}_core-metrics-results/unweighted_unifrac_distance_matrix.qza ${project}_metadata.tsv ${project}
            ;;
            "9")
            feature_classifier ${project}_rep-seqs-dada2.qza ${project}_taxonomy.qza
            ;;
            "10")
            taxa_barplot ${project}_table-dada2.qza ${project}_taxonomy.qza ${project}_metadata.tsv ${project}_taxa-bar-plots.qzv
            ;;
            "11")
            mv ${project}_table-dada2.qza ${project}_unfilter_table-dada2.qza
            filter_table ${project}_unfilter_table-dada2.qza ${project}_taxonomy.qza ${project}_table-dada2.qza
            ;;
            "12")
            tools_export ${project}_table-dada2.qza exported_${project} ${project}_unrooted-tree.qza exported_${project}_tree.qza
            ;;
            "13")
            sample_classifier ${project}_table-dada2.qza ${project}_metadata.tsv ${project}_sample-classifier-results
            ;;
            "14")
            importance ${project}_sample-classifier-results/feature_importance.qza ${project}_sample-classifier-results/feature_importance.qzv
            ;;
            "15")
            mv ${project}_paired-end-demux_seqs.qza ${project}_paired-uncut-end-demux_seqs.qza
            mv ${project}_paired-end-demux_seqs.qzv ${project}_paired-uncut-end-demux_seqs.qzv
            cutadapt_paired_primer ${project}_paired-uncut-end-demux_seqs.qza ${project}_paired-end-demux_seqs.qza
            import_visualization ${project}_paired-end-demux_seqs
            ;;
            "16")
            mv ${project}_single-end-demux_seqs.qza ${project}_single-uncut-end-demux_seqs.qza
            mv ${project}_single-end-demux_seqs.qzv ${project}_single-uncut-end-demux_seqs.qzv
            cutadapt_single_primer ${project}_single-uncut-end-demux_seqs.qza ${project}_single-end-demux_seqs.qza
            import_visualization ${project}_single-end-demux_seqs
            ;;
            "17")
            vsearch_join_pairs ${project}_paired-end-demux_seqs.qza ${project}_paired-end-demux-joined.qza
            demux_summarize ${project}_paired-end-demux-joined
            ;;
            "18")
            deblur_denoise ${project}_paired-end-demux-joined.qza ${project}_rep-seqs-deblur.qza ${project}_table-deblur ${project}_stats-deblur ${project}_metadata.tsv
            ;;
            "19")
            feature_table_rarefy ${project}_table-dada2
            ;;
            esac
        read -p "Do you want stop? please input N/n to stop!" yn
    done
    conda deactivate
fi