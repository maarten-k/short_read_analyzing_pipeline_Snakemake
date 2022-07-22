import pandas as pd
import read_stats
import os
configfile: "Snakefile.cluster.json"
configfile: "Snakefile.paths.yaml"
gatk = config['miniconda'] + config['gatk']
samtools = config['miniconda'] + config['samtools']
bcftools = config['miniconda'] + config['bcftools']
dragmap = config['miniconda'] + config['dragmap']
cutadapt = config['miniconda'] + config['cutadapt']
verifybamid2 = config['miniconda'] + config['verifybamid2']

ref = config['RES'] + config['ref']
chrs = ['chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10', 'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 'chr19', 'chr20', 'chr21', 'chr22', 'chrX', 'chrY']


# (SAMPLE,) = glob_wildcards("/projects/0/qtholstg/fastq_test/{sample}_cut_1.fq.gz")

from read_samples import *
from common import *

# read samplefile as csv and store
sample_information = pd.read_csv("NL_VUMC_test_2.tsv", sep='\t', index_col=False, header = None)

# extract SN from samplefile
sample_names = list(sample_information[1])
#
# # extract paths to files from SampleFile
# for_paths = list(sample_information[6])
# rev_paths = list(sample_information[7])

def get_fastqpaired(wildcards):
    # command to extract path to fastq files from samplefile
    sinfo = SAMPLEINFO[wildcards['sample']] # SMAPLEINFO comes from common.py, it's dict created from samplefile
    # check readgroups
    readgroup = [readgroup for readgroup in sinfo['readgroups'] if readgroup['info']['ID'] == wildcards['readgroup']][0]
    # SAMPLEFOLDER it's path folder
    # maybe created symlinks to folder with all fq easier?
    # ln -s
    file1 = os.path.join(config['SAMPLEFOLDER'], readgroup['file1'])
    if file1.endswith('.bz2'):
        file1 = file1[:-4] + '.gz'
    file2 = os.path.join(config['SAMPLEFOLDER'], readgroup['file2'])
    if file2.endswith('.bz2'):
        file2 = file2[:-4] + '.gz'
    return [file1,file2]

def get_readgroups(wildcards):
    readgroups = SAMPLEINFO[wildcards['sample']]['readgroups']
    files = []
    for readgroup in readgroups:
        files.append(os.path.join(config['BAM'] + '/' + wildcards['sample'] + '.' + readgroup['info']['ID'] + '.bam'))
    return files

rule all:
    input:
        expand("{bams}/{sample}-dragstr.txt", bams = config['BAM'], sample = sample_names)
        # expand("{bams}/{sample}.merged.bam", sample = sample_names, bams = config['BAM']),
        # # expand(config['STAT'] + "/{sample}.{readgroup}_adapters.stat", sample = sample_names)
        # config['STAT'] + "/BASIC.variant_calling_detail_metrics",
        # # # sample_names from sample file accord to all samples
        # # # expanded version accord to all samples listed in samplefile
        # expand("{stats}/{sample}_hs_metrics",sample=sample_names, stats = config['STAT']),
        # expand("{stats}/{sample}.bait_bias.bait_bias_detail_metrics", sample=sample_names, stats = config['STAT']),
        # expand("{stats}/{sample}.OXOG", sample=sample_names, stats = config['STAT']),
        # expand("{stats}/{sample}_coverage.cov", sample=sample_names, stats = config['STAT']),
        # expand("{stats}/{sample}_samtools.stat", sample=sample_names, stats = config['STAT']),
        # expand("{vcf}/Merged_raw_DBI_{chrs}.vcf.gz", chrs = chrs, vcf = config['VCF']),
        # expand("{vcf}/ALL_chrs.vcf.gz", vcf = config['VCF']),
        # expand("{stats}/{sample}_verifybamid.selfSM", sample=sample_names, stats = config['STAT']),
        # expand("{stats}/{sample}.bam_all.tsv", sample=sample_names, stats = config['STAT']),
        # expand("{samplefile}.oxo_quality.tab", samplefile = "NL_VUMC_test_2.tsv"),
        # expand("{samplefile}.bam_quality.v4.tab", samplefile = "NL_VUMC_test_2.tsv")

#just alignment and convert to bams

# rule mask_adapters:
#     input:
#         # for_paths,
#         # rev_paths
#         get_fastqpaired,
#     output:
#         ubam = temp(config['BAM'] + "/{sample}.{readgroup}.unmapped.bam"),
#         maskedbam = config['BAM'] + "/{sample}.{readgroup}_masked_unmapped.bam",
#         adapters_stats = config['STAT'] + "/{sample}.{readgroup}_adapters.stat"
#     benchmark: config['BENCH'] + "/{sample}.{readgroup}.maskadapters.txt"
#     log:
#         fqtosam = config['LOG'] + '/' + "{sample}.{readgroup}.fq2sam.log",
#         adapters = config['LOG'] + '/' + "{sample}.{readgroup}.adapters.log"
#     # shell:"""
#     #     {gatk} FastqToSam --FASTQ {input[0]} --FASTQ2 {input[1]} -O {output.ubam} -SM {wildcards.sample} &&
#     #     {gatk} MarkIlluminaAdapters -I {output.ubam} -O {output.maskedbam} -M {output.adapters_stats}
#     # """
#     run:
#         sinfo = SAMPLEINFO[wildcards['sample']]
#         rgroup = \
#         [readgroup for readgroup in sinfo['readgroups'] if readgroup['info']['ID'] == wildcards['readgroup']][0]['info']
#         rgroupid = rgroup['ID']
#         rgrouplib = rgroup.get('LB','unknown')
#         rgroupplat = rgroup.get('PL','unknown')
#         rgrouppu = rgroup.get('PU','unknown')
#         rgroupsc = rgroup.get('CN','unknown')
#         rgrouprd = rgroup.get('DT','unknown')
#
#         rgline = '@RG\\tID:%s\\tSM:%s' % (rgroupid, wildcards['sample'])
#         if 'DT' in rgroup:
#             rgline += '\\tDT:%s' % rgroup['DT']
#         if 'CN' in rgroup:
#             rgline += '\\tCN:%s' % rgroup['CN']
#         if 'LB' in rgroup:
#             rgline += '\\tLB:%s' % rgroup['LB']
#         if 'PL' in rgroup:
#             rgline += '\\tPL:%s' % rgroup['PL']
#         if 'PU' in rgroup:
#             rgline += '\\tPU:%s' % rgroup['PU']
#         cmd="""
#         {gatk} FastqToSam --FASTQ {input[0]} --FASTQ2 {input[1]} -O {output.ubam} -SM {wildcards.sample} -RG {wildcards.readgroup} 2> {log.fqtosam} &&
#         {gatk} MarkIlluminaAdapters -I {output.ubam} -O {output.maskedbam} -M {output.adapters_stats} 2> {log.adapters}
#         """
#         shell(cmd)

rule cutadapter:
    input:
        get_fastqpaired
    output:
        forr_f=config['FQ'] + "/{sample}.{readgroup}.cut_1.fq.gz",
        rev_f=config['FQ'] + "/{sample}.{readgroup}.cut_2.fq.gz"
    log:
        cutadapt_log= config['LOG'] + "/{sample}.{readgroup}.cutadapt.log",
    benchmark:
        config['BENCH'] + "/{sample}.{readgroup}.cutadapt.txt"
    priority: 10
    threads: config["cutadapter"]["n"]
    run:
        sinfo = SAMPLEINFO[wildcards['sample']]
        rgroup = [readgroup for readgroup in sinfo['readgroups'] if readgroup['info']['ID'] == wildcards['readgroup']][0]['info']
        rgroupid = rgroup['ID']
        rgrouplib = rgroup.get('LB','unknown')
        rgroupplat = rgroup.get('PL','unknown')
        rgrouppu = rgroup.get('PU','unknown')
        rgroupsc = rgroup.get('CN','unknown')
        rgrouprd = rgroup.get('DT','unknown')
        # cut standard Illumina adapters
        cmd="""
        {cutadapt} -j {threads} -m 100 -a AGATCGGAAGAG -A AGATCGGAAGAG -o {output.forr_f} -p {output.rev_f} {input[0]} {input[1]} &> {log.cutadapt_log}
        """
        shell(cmd)
    # shell:
    #     """
    #     {cutadapt} -j {threads} -m 100 -a AGATCGGAAGAG -A AGATCGGAAGAG -o {output.forr_f} -p {output.rev_f} {input} 2> {log}
    #     """


rule align_reads:
    input:
        for_r = rules.cutadapter.output.forr_f,
        rev_r = rules.cutadapter.output.rev_f
        # rules.mask_adapters.output.maskedbam
        # forward="/projects/0/qtholstg/fastq_test/{sample}_cut_1.fq.gz",
        # rev="/projects/0/qtholstg/fastq_test/{sample}_cut_2.fq.gz"
    output:
        bam=config['BAM'] + "/" + "{sample}.{readgroup}.bam"
    params:
        ref_dir = config['RES'] + config['ref_dir'],
        mask_bed = config['RES'] + config['mask_bed']
    threads: config["align_reads"]["n"]
    log:
        dragmap_log=config['LOG'] + '/' + "{sample}.{readgroup}_dragmap.log",
        samtools_fixmate=config['LOG'] + '/' + "{sample}.{readgroup}_samtools_fixamte.log",
        samtools_sort=config['LOG'] + '/' + "{sample}.{readgroup}_samtools_sort.log",
        samtools_markdup=config['LOG'] + '/' + "{sample}.{readgroup}_samtools_markdup.log",
        samtools_index = config['LOG'] + '/' + "{sample}.{readgroup}_samtools_index.log"
    benchmark:
        config['BENCH'] + "/{sample}.{readgroup}.dragmap.txt"
    priority: 15
    shell:
        # "{dragmap} -r {params.ref_dir} -b {input} --RGID {wildcards.readgroup} --RGSM {wildcards.sample}  --ht-mask-bed {params.mask_bed} --num-threads {threads} 2> {log.dragmap_log} |"
        "{dragmap} -r {params.ref_dir} -1 {input.for_r} -2 {input.rev_r} --RGID {wildcards.readgroup} --RGSM {wildcards.sample}  --ht-mask-bed {params.mask_bed} --num-threads {threads} 2> {log.dragmap_log} |" 
        "{samtools} fixmate -@ {threads} -m - -  &> {log.samtools_fixmate} | "
        "{samtools} sort -T 'sort_temporary' -@ {threads}  -o {output.bam} &> {log.samtools_sort} &&"
        "{samtools} index -@ {threads} {output.bam} &> {log.samtools_index}"

rule merge_rgs:
    input:
        get_readgroups
    output:
        mer_bam = (config['BAM'] + "/{sample}.merged.bam")
    log: config['LOG'] + '/' + "{sample}.mergereadgroups.log"
    benchmark: "benchmark/{sample}.merge_rgs.txt"
    threads: config['merge_rgs']['n']
    run:
        inputs = ' '.join(f for f in input if f.endswith('.bam'))
        shell("{samtools} merge -@ {threads} -o {output} {inputs} &> {log}")

rule markdup:
    input:
        rules.merge_rgs.output.mer_bam
    output:
        mdbams = config['BAM'] + "/{sample}.markdup.bam",
        MD_stat = config['STAT'] + "/{sample}.markdup.stat"
    benchmark: "benchmark/{sample}.markdup.txt"
    params:
        machine = 2500 #change to function
    # 100 for HiSeq and 2500 for NovaSeq
    log:
        samtools_markdup = config['LOG'] + '/' + "{sample}.markdup.log",
        samtools_index_md = config['LOG'] + '/' + "{sample}.markdup_index.log"
    threads: config['markdup']['n']
    shell:
        "{samtools} markdup -f {output.MD_stat} -S -d {params.machine} -@ {threads} {input} {output.mdbams} &> {log.samtools_markdup} && "
        "{samtools} index -@ {threads} {output.mdbams} 2> {log.samtools_index_md}"

        # merge bam files here, add rule, option sort order
        # 
        # additional ruleto markdup
        # "{samtools} markdup -@ {threads} - {output.bam} 2> {log.samtools_markdup} && "
        # add -S flag, find what it does 
        # -d for optical duplicates
        # optical duplicates depends on machine
        # zcat fastq/90-492165764/SVDL_KG-010048/KG-010048_R1_001.fastq.gz | grep '@' | awk -F ':' '{print $3}' | head
        # extract part of fq file where machine code is coded
        # https://github.com/10XGenomics/supernova/blob/master/tenkit/lib/python/tenkit/illumina_instrument.py#L12-L45
        # dictionary of machines
        # "{samtools} index -@ {threads} {output.bam} 2> {log.samtools_index}"
        # "{dragmap} -r {params.ref_dir} -1 {input[0]} -2 {input[1]} --RGID {wildcards.sample} --RGSM {wildcards.sample} --ht-mask-bed {params.mask_bed} --num-threads {threads} 2> {log.dragmap_log} | "
        # "{samtools} fixmate -@ {threads} -m - -  2> {log.samtools_fixmate} | "
        # "{samtools} sort -T 'sort_temorary' -@ {threads}  2> {log.samtools_sort} | "
        # "{samtools} markdup -@ {threads} - {output.bam} 2> {log.samtools_markdup} && "
        # "{samtools} index -@ {threads} {output.bam} 2> {log.samtools_index}"

# bam_stats.py
# IF supplemetary fraction > 0.5%
# sort in query_name
# run bam_clean.py
# sort by pos
# bam_stats.py post cleaning
#

# rule bamstats_all:
checkpoint bamstats_all:
    input:
        rules.markdup.output.mdbams
    output:
        All_stats = config['STAT'] + '/{sample}.bam_all.tsv'
    threads: config['bamstats_all']['n']
    params: py_stats = config['BAMSTATS']
    shell:
        "{samtools} view -s 0.05 -h {input} --threads {threads} | python3 {params.py_stats} stats > {output}"


rule resort_by_readname:
    input:
        rules.markdup.output.mdbams
    output: resort_bams = temp(config['BAM'] + '/{sample}_resort.bam')
    threads: config['resort_by_readname']['n']
    shell: "{samtools} sort -n -@ {threads} -o  {output} {input}"

rule declip:
    input:
        rules.resort_by_readname.output.resort_bams
    output: declip_bam = temp(config['BAM'] + '/{sample}_declip.bam')
    threads: config['declip']['n']
    params: declip = config['DECLIP']
    shell:
        "{samtools} view -s 0.05 -h {input} --threads {threads} | python3 {params.declip} > {output}"

rule sort_back:
    input:
        rules.declip.output.declip_bam
    output: ready_bams = config['BAM'] + '/{sample}.DeClipped.bam'
    threads: config['sort_back']['n']
    params:
        old_stats = rules.bamstats_all.output.All_stats,
        new_path_to_old_stats = config['STAT'] + '/expired/{sample}.bam_all_expired.tsv'
    shell:
        "{samtools} sort -@ {threads} -o {output} {input}"
        "{samtools} index -@ {threads} {output}"
        "mv {params.old_stats} {params.new_path_to_old_stats}"



def check_supp(wildcards):
    with checkpoints.bamstats_all.get(sample=wildcards.sample).output[0].open() as f:
        lines = f.readlines()
        if float((lines[1].split()[3])) >= float(0.003):
            return rules.sort_back.output.ready_bams
        else:
            return rules.markdup.output.mdbams

def check_supp_stats(wildcards):
    with checkpoints.bamstats_all.get(sample=wildcards.sample).output[0].open() as f:
        lines = f.readlines()
        if float((lines[1].split()[3])) >= float(0.003):
            return rules.bamstat_new.output.All_stats
        else:
            return rules.bamstats_all.output.All_stats


rule bamstats_new:
    input:
        check_supp
    output:
        All_stats = config['STAT'] + '/{sample}.bam_all.tsv'
    threads: config['bamstats_new']['n']
    params: py_stats = config['BAMSTATS']
    shell:
        "{samtools} view -s 0.05 -h {input} --threads {threads} | python3 {params.py_stats} stats > {output}"

rule CalibrateDragstrModel:
    input:
        check_supp
    output:
        dragstr_model = config['BAM'] + "/{sample}-dragstr.txt"
    priority: 16
    params:
        str_ref = config['RES'] + config['str_ref']
    log: config['LOG'] + '/' + "{sample}_calibratedragstr.log"
    benchmark: config['BENCH'] + "/{sample}_calibrate_dragstr.txt"
    shell:
        "{gatk} CalibrateDragstrModel -R {ref} -I {input} -O {output} -str {params.str_ref} 2>{log}"

#find SNPs from bams
rule HaplotypeCaller:
    input:
        bams = check_supp,
        model = rules.CalibrateDragstrModel.output.dragstr_model
    output:
        gvcf=temp("gvcfs/{sample}.g.vcf.gz"),
    log:
        HaplotypeCaller=config['LOG'] + '/' + "{sample}_haplotypecaller.log"
    benchmark:
        config['BENCH'] + "/{sample}_haplotypecaller.txt"
    params:
        dbsnp = config['RES'] + config['dbsnp'],
        interval = config['interval'],
        padding=150  # extend intervals to this bp
    priority: 25
    shell:
        # interval should be extended
        "{gatk} HaplotypeCaller \
                 -R {ref} -L {params.interval} -ip {params.padding} -D {params.dbsnp} -ERC GVCF \
                 -G StandardAnnotation -G AS_StandardAnnotation -G StandardHCAnnotation \
                 -I {input.bams} -O {output.gvcf} --dragen-mode true --dragstr-params-path {input.model} 2> {log.HaplotypeCaller}"
#############################################################################################
#############################################################################################

#Genomics DBImport instead CombineGVCFs
# run parts of chrs instead of full chr (at least fisrt 10)
rule GenomicDBImport:
    input:
        expand("gvcfs/{sample}.g.vcf.gz", sample = sample_names)
    log: config['LOG'] + '/' + "GenomicDBImport.{chrs}.log"
    benchmark: config['BENCH'] + "/GenomicDBImport.{chrs}.txt"
    output:
        dbi=directory("genomicsdb_{chrs}")
    threads: config['GenomicDBImport']['n']
    # params:
        # N_intervals=5,
        # threads=16,
        # padding = 100
    priority: 30
    shell:
        "ls gvcfs/*.g.vcf.gz > gvcfs.list && {gatk} GenomicsDBImport --reader-threads {threads}\
        -V gvcfs.list --intervals {wildcards.chrs}  -R {ref} --genomicsdb-workspace-path {output} --genomicsdb-shared-posixfs-optimizations true --bypass-feature-reader 2> {log}"
        # "ls gvcfs/*.g.vcf > gvcfs.list && {gatk} GenomicsDBImport -V gvcfs.list --intervals {chrs}  -R {ref} --genomicsdb-workspace-path {output} \
        #      --max-num-intervals-to-import-in-parallel {params.N_intervals} --reader-threads {params.threads}"

# genotype
rule GenotypeDBI:
    input:
        rules.GenomicDBImport.output.dbi
    output:
        raw_vcfDBI=config['VCF'] + "/Merged_raw_DBI_{chrs}.vcf.gz"
    log: config['LOG'] + '/' + "GenotypeDBI.{chrs}.log"
    benchmark: config['BENCH'] + "/GenotypeDBI.{chrs}.txt"
    params:
        padding=150,
        dbsnp = config['RES'] + config['dbsnp']
    priority: 40
    shell:
            "{gatk} GenotypeGVCFs -R {ref} -V gendb://{input} -O {output} -D {params.dbsnp} --intervals {wildcards.chrs} 2> {log}"

# don't merge before VQSR
rule Mergechrs:
    input:
        expand(config['VCF'] + "/Merged_raw_DBI_{chrs}.vcf.gz", chrs = chrs)
    params:
        vcfs = list(map("-I vcfs/Merged_raw_DBI_{}.vcf.gz".format, chrs))
    log: config['LOG'] + '/' + "Mergechrs.log"
    benchmark: config['BENCH'] + "/Mergechrs.txt"
    output:
        vcf = config['VCF'] + "/ALL_chrs.vcf.gz"
    priority: 45
    shell:
        "{gatk} GatherVcfs {params.vcfs} -O {output} -R {ref} 2> {log} && {gatk} IndexFeatureFile -I {output} "


# VQSR
#select SNPs for VQSR
# SNPs and INDELs require different options
rule SelectSNPs:
    input:
        rules.Mergechrs.output.vcf
    output:
        SNP_vcf=temp(config['VCF'] + "/Merged_SNPs.vcf")
    priority: 50
    log: config['LOG'] + '/' + "SelectSNPs.log"
    benchmark: config['BENCH'] + "/SelectSNPs.txt"
    shell:
        """
        {gatk} SelectVariants \
                --select-type-to-include SNP \
                -V {input} -O {output} 2> {log}
        """

# 1st step of VQSR - calculate scores
rule VQSR_SNP:
    input:
        rules.SelectSNPs.output.SNP_vcf
    output:
        recal_snp=temp(config['VCF'] + "/SNPs_vqsr.recal"),
        tranches_file_snp=temp(config['VCF'] + "/SNPs_vqsr.tranches"),
        r_snp=config['STAT'] + "/SNPs_vqsr_plots.R"
    log: config['LOG'] + '/' + "VQSR_SNP.log"
    benchmark: config['BENCH'] + "/VQSR_SNP.txt"
    params:
        hapmap = config['RES'] + config['hapmap'],
        omni = config['RES'] + config['omni'],
        kilo_g = config['RES'] + config['kilo_g'],
        dbsnp = config['RES'] + config['dbsnp']
    priority: 55
    shell:
        # -an InbreedingCoeff if 10+
        """
        {gatk} VariantRecalibrator\
         -R {ref} -V {input} \
         -resource:hapmap,known=false,training=true,truth=true,prior=15.0 {params.hapmap} \
         -resource:omni,known=false,training=true,truth=true,prior=12.0 {params.omni} \
         -resource:1000G,known=false,training=true,truth=false,prior=10.0 {params.kilo_g} \
         -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 {params.dbsnp} \
         -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an DP -mode SNP \
         --trust-all-polymorphic -AS TRUE\
         -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 \
         -O {output.recal_snp} \
         --tranches-file {output.tranches_file_snp} \
         --rscript-file {output.r_snp} 2> {log}
        """

rule ApplyVQSR_SNPs:
    input:
        recal_snp=rules.VQSR_SNP.output.recal_snp,
        tranches_snp=rules.VQSR_SNP.output.tranches_file_snp,
        snps_variants=rules.SelectSNPs.output.SNP_vcf
    output:
        recal_vcf_snp=temp(config['VCF'] + "/SNPs_recal_apply_vqsr.vcf")
    log: config['LOG'] + '/' + "Apply_VQSR_SNP.log"
    benchmark: config['BENCH'] + "/Apply_VQSR_SNP.txt"
    params:
        ts_level='99.0'  #ts-filter-level show the "stregnth" of VQSR could be from 90 to 100
    priority: 60
    shell:
        """
        {gatk} ApplyVQSR -R {ref} -mode SNP \
        --recal-file {input.recal_snp} --tranches-file {input.tranches_snp} \
        -O {output} -V {input.snps_variants} -ts-filter-level {params.ts_level} -AS TRUE 2> {log}
        """

# select INDELs for VQSR
rule SelectINDELs:
    input:
        rules.Mergechrs.output.vcf
    output:
        INDEL_vcf=temp(config['VCF'] + "/Merged_INDELs.vcf")
    log: config['LOG'] + '/' + "SelectINDELS.log"
    benchmark: config['BENCH'] + "/SelectINDELs.txt"
    priority: 50
    shell:
        """
        {gatk} SelectVariants \
                --select-type-to-include INDEL \
                -V {input} -O {output} 2> {log}
        """

# 1st step of VQSR - calculate scores
rule VQSR_INDEL:
    input:
        rules.SelectINDELs.output.INDEL_vcf
    output:
        recal_indel=temp(config['VCF'] + "/INDELs_vqsr.recal"),
        tranches_file_indel=temp(config['VCF'] + "/INDELs_vqsr.tranches"),
        r_indel=config['STAT'] + "/INDELs_vqsr_plots.R"
    log: config['LOG'] + '/' + "VQSR_INDEL.log"
    benchmark: config['BENCH'] + "/VQSR_INDEL.txt"
    priority: 55
    params:
        mills = config['RES'] + config['mills'],
        dbsnp_indel = config['RES'] + config['dbsnp_indel']
    shell:
        # -an InbreedingCoeff if 10+
        """
        {gatk} VariantRecalibrator -R {ref} -V {input} \
        -O {output.recal_indel} --tranches-file {output.tranches_file_indel} --rscript-file {output.r_indel} \
         --max-gaussians 4 --trust-all-polymorphic -AS TRUE\
         -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 \
         -resource:mills,known=false,training=true,truth=true,prior=12.0 {params.mills} \
         -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 {params.dbsnp_indel} \
         -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum -mode INDEL \
         --trust-all-polymorphic 2> {log}
        """

rule ApplyVQSR_INDEs:
    input:
        recal_indel=rules.VQSR_INDEL.output.recal_indel,
        tranches_indel=rules.VQSR_INDEL.output.tranches_file_indel,
        indel_variants=rules.SelectINDELs.output.INDEL_vcf
    log: config['LOG'] + '/' + "ApplyVQSR_INDELs.log"
    benchmark: config['BENCH'] + "/ApplyVQSR_INDELs.txt"
    output:
        recal_vcf_indel=temp(config['VCF'] + "/INDELs_recal_apply_vqsr.vcf")
    params:
        ts_level='97.0'  #ts-filter-level show the "stregnth" of VQSR could be from 90 to 100
    priority: 60
    shell:
        """
        {gatk} ApplyVQSR -R {ref} -mode INDEL \
        --recal-file {input.recal_indel} --tranches-file {input.tranches_indel} \
        -O {output} -V {input.indel_variants} -ts-filter-level {params.ts_level} -AS TRUE 2> {log}
        """

#combine filtr results
rule combine:
    input:
        snps=rules.ApplyVQSR_SNPs.output.recal_vcf_snp,
        indel=rules.ApplyVQSR_INDEs.output.recal_vcf_indel
    log: config['LOG'] + '/' + "combine.log"
    benchmark: config['BENCH'] + "/combine.txt"
    output:
        filtrVCF=config['VCF'] + "/Merged_after_VQSR.vcf"
    priority: 70
    shell:
        "{gatk} MergeVcfs \
                -I {input.snps} -I {input.indel} -O {output} 2> {log}"

# normalization with bcftools
rule norm:
    input:
        rules.combine.output.filtrVCF
    output:
        normVCF=config['VCF'] + "/Merged_after_VQSR_norm.vcf",
        idx=config['VCF'] + "/Merged_after_VQSR_norm.vcf.idx"
    log: config['LOG'] + '/' + "normalization.log"
    benchmark: config['BENCH'] + "/normalization.txt"
    priority: 80
    shell:
        "{bcftools} norm -f {ref} {input} -m -both -O v | {bcftools} norm -d exact -f {ref} > {output.normVCF} 2> {log} && {gatk} IndexFeatureFile -I {output.normVCF} -O {output.idx} "

# basic stats
# include hom-het ratio, titv ratio, etc.
rule Basic_stats:
    input:
        rules.norm.output.normVCF
    output:
        config['STAT'] + "/BASIC.variant_calling_detail_metrics",
        config['STAT'] + "/BASIC.variant_calling_summary_metrics"
    priority: 90
    log: config['LOG'] + '/' + "VCF_stats.log"
    benchmark: config['BENCH'] + "/VCF_stats.txt"
    params: dbsnp = config['RES'] + config['dbsnp']
    threads: config['Basic_stats']['n']
    shell:
        "{gatk} CollectVariantCallingMetrics \
        -R {ref} -I {input} -O stats/BASIC \
        --DBSNP {params.dbsnp} --THREAD_COUNT {threads} 2> {log}"

#hsmetrics
#include off-target metrics
rule HS_stats:
    input:
        rules.markdup.output.mdbams
    output:
        HS_metrics=config['STAT'] + "/{sample}_hs_metrics"
    log: config['LOG'] + '/' + "HS_stats_{sample}.log"
    benchmark: config['BENCH'] + "/HS_stats_{sample}.txt"
    priority: 99
    params:
        interval = config['interval'],
        #minimum Base Quality for a base to contribute cov
        #def is 20
        Q=10,
        #minimin Mapping Quality for a read to contribute cov
        #def is 20
        MQ=10,
    #padding = 100
    shell:
        "{gatk} CollectHsMetrics \
            -I {input} -R {ref} -BI {params.interval} -TI {params.interval} \
            -Q {params.Q} -MQ {params.MQ} \
            --PER_TARGET_COVERAGE stats/{wildcards.sample}_per_targ_cov \
            -O stats/{wildcards.sample}_hs_metrics 2> {log}"

rule Artifact_stats:
    input:
        rules.markdup.output.mdbams
    output:
        Bait_bias = config['STAT'] + "/{sample}.bait_bias.bait_bias_summary_metrics",
        Pre_adapter = config['STAT'] + "/{sample}.bait_bias.pre_adapter_summary_metrics"
        # Artifact_matrics = config['STAT'] + "/{sample}.bait_bias.bait_bias_detail_metrics"
    priority: 99
    log: config['LOG'] + '/' + "Artifact_stats_{sample}.log"
    benchmark: config['BENCH'] + "/Artifact_stats_{sample}.txt"
    params:
        # output define prefix, not full filename
        # params.out define prefix and output define whole outputs' filename
        out = config['STAT'] + "/{sample}.bait_bias",
        interval = config['interval'],
        dbsnp = config['RES'] + config['dbsnp']
    shell:
        "{gatk} CollectSequencingArtifactMetrics -I {input} -O {params.out} -R {ref} --DB_SNP {params.dbsnp} --INTERVALS {params.interval} 2> log"

rule OXOG_metrics:
    input:
        rules.markdup.output.mdbams
    output:
        Artifact_matrics = config['STAT'] + "/{sample}.OXOG"
    priority: 99
    log: config['LOG'] + '/' + "OXOG_stats_{sample}.log"
    benchmark: config['BENCH'] + "/OxoG_{sample}.txt"
    params:
        interval = config['interval'],
        dbsnp = config['RES'] + config['dbsnp']
    shell:
        "{gatk} CollectOxoGMetrics -I {input} -O {output} -R {ref} --DB_SNP {params.dbsnp} --INTERVALS {params.interval} 2> {log}"

rule samtools_stat:
    input:
        rules.markdup.output.mdbams
    output: samtools_stat = config['STAT'] + "/{sample}_samtools.stat"
    priority: 99
    log: config['LOG'] + '/' + "samtools_{sample}.log"
    benchmark: config['BENCH'] + "/samtools_stat_{sample}.txt"
    threads: config['samtools_stat']['n']
    shell:
        "{samtools} stat -@ {threads} -r {ref} {input} > {output}"

rule samtools_stat_exome:
    input:
        rules.markdup.output.mdbams
    output: samtools_stat_exome = config['STAT'] + "/{sample}_samtools.exome.stat"
    priority: 99
    log: config['LOG'] + '/' + "samtools_exome_{sample}.log"
    benchmark: config['BENCH'] + "/samtools_stat_exome_{sample}.txt"
    params:
        bed_interval = config['kit_bed']
    threads: config['samtools_stat']['n']
    shell:
        "{samtools} stat -@ {threads} -t {params.bed_interval} -r {ref} {input} > {output}"
#
# rule samtools_cov:
#     input:
#         rules.markdup.output.mdbams
#     output: samtools_stat = config['STAT'] + "/{sample}_coverage.cov"
#     priority: 99
#     log: config['LOG'] + '/' + "coverage_{sample}.log"
#     benchmark: config['BENCH'] + "/samtools_cov_{sample}.txt"
#     params:
#         MQ = 10, # mapping quality threshold, default 0
#         BQ = 10 # base quality threshold, default 0
#     shell:
#         "{samtools} coverage -q {params.MQ} -Q {params.BQ} -o {output} {input}"


# verifybamid
# capture_kit = SAMPLEINFO[wildcards['sample']]['capture_kit']

rule verifybamid:
    input:
        rules.markdup.output.mdbams
    output:
        VBID_stat = config['STAT'] + '/{sample}_verifybamid.selfSM'
    threads: config['verifybamid']['n']
    params:
        VBID_prefix = config['STAT'] + '/{sample}_verifybamid',
        SVD = config['RES'] + config['verifybamid_exome']
    shell:
        """
        set +u
        source ~/bin/start_conda
        PS1=''
        conda info --envs
        source activate verifybamid
        set -u
        verifybamid2 --BamFile {input} --SVDPrefix {params.SVD} --Reference {ref} --DisableSanityCheck --NumThread {threads} --Output {params.VBID_prefix}
        """


rule bamstats_exome:
    input:
        rules.markdup.output.mdbams
    output:
        All_exome_stats = config['STAT'] + '/{sample}.bam_exome.tsv'
    threads: config['bamstats_exome']['n']
    params:
        py_stats = config['BAMSTATS'],
        bed_interval = config['kit_bed']
    shell:
        "samtools view -s 0.05 -h {input} --threads {threads} -L {params.bed_interval} | python3 {params.py_stats} stats > {output}"


def get_quality_stats(wildcards):
    sampleinfo = SAMPLES_BY_FILE[os.path.basename(wildcards['samplefile'])]
    files = []
    samples = list(sampleinfo.keys())
    samples.sort()
    for sample in samples:
        files.append(config['STAT'] + '/' + sample + "_samtools.stat")
        files.append(config['STAT'] + '/' + sample + '_samtools.exome.stat')
        files.append(config['STAT'] + '/' + sample + '_verifybamid.selfSM')
        files.append(config['STAT'] + '/' + sample + '.bam_all.tsv')
        files.append(config['STAT'] + '/' + sample + '.bam_exome.tsv')
        files.append(config['STAT'] + '/' + sample + '.bait_bias.pre_adapter_summary_metrics')
        files.append(config['STAT'] + '/' + sample + '.bait_bias.bait_bias_summary_metrics')
    return files


rule gatherstats:
    input:
        get_quality_stats
    output:
        '{samplefile}.bam_quality.v4.tab'
    run:
        sampleinfo = SAMPLES_BY_FILE[os.path.basename(wildcards['samplefile'])]
        samples = list(sampleinfo.keys())
        samples.sort()

        rinput = numpy.array(input).reshape(len(samples),int(len(input) / len(samples)))
        stats, exome_stats, vpca2, bam_extra_all, bam_extra_exome, pre_adapter, bait_bias = zip(*rinput)

        header, data = read_stats.combine_quality_stats(samples,stats,exome_stats,vpca2,bam_extra_all,bam_extra_exome,pre_adapter,bait_bias)
        read_stats.write_tsv(str(output),header,data)


def get_oxo_stats(wildcards):
    sampleinfo = SAMPLES_BY_FILE[os.path.basename(wildcards['samplefile'])]
    directory = os.path.dirname(wildcards['samplefile'] + '.tsv')
    basename = os.path.basename(wildcards['samplefile'])

    files = []
    samples = list(sampleinfo.keys())
    samples.sort()
    for sample in samples:
        files.append(config['STAT'] + '/' + sample + '.bait_bias.pre_adapter_detail_metrics')
        files.append(config['STAT'] + '/' + sample + '.bait_bias.bait_bias_detail_metrics')
    return files


rule gatherosostats:
    input:
        get_oxo_stats
    output:
        '{samplefile}.oxo_quality.tab'
    run:
        sampleinfo = SAMPLES_BY_FILE[os.path.basename(wildcards['samplefile'])]
        samples = list(sampleinfo.keys())
        samples.sort()

        rinput = numpy.array(input).reshape(len(samples),int(len(input) / len(samples)))
        pre_adapter, bait_bias = zip(*rinput)

        header, data = read_stats.combine_oxo_stats(samples,pre_adapter,bait_bias)
        read_stats.write_tsv(str(output),header,data)


