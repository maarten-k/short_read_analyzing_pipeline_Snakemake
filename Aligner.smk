import pandas as pd
import read_stats
import os
import getpass
configfile: srcdir("Snakefile.cluster.json")
configfile: srcdir("Snakefile.paths.yaml")

ref = os.path.join(config['RES'], config['ref'])
tmpdir = os.path.join(config['TMPDIR'], getpass.getuser())


os.makedirs(tmpdir, mode=0o700, exist_ok=True)

wildcard_constraints:
    sample="[\w\d_\-@]+",
    readgroup="[\w\d_\-@]+"


from read_samples import *
from common import *
SAMPLE_FILES, SAMPLEFILE_TO_SAMPLES, SAMPLEINFO = load_samplefiles('.', config)

# extract all sample names from SAMPLEINFO dict to use it rule all
sample_names = SAMPLEINFO.keys()

rule Aligner_all:
    input:
        expand("{bams}/{sample}.merged.bam", sample=sample_names, bams=config['BAM']),
        expand("{cram}/{sample}_mapped_hg38.cram", cram = config['CRAM'], sample=sample_names),
    default_target: True



#just alignment and convert to bams

def get_fastqpaired(wildcards):
    # command to extract path to fastq files from samplefile
    sinfo = SAMPLEINFO[wildcards['sample']]  # SMAPLEINFO comes from common.py, it's dict created from samplefile
    # check readgroups
    readgroup = [readgroup for readgroup in sinfo['readgroups'] if readgroup['info']['ID'] == wildcards['readgroup']][0]
    file1 = os.path.join(readgroup['prefix'], readgroup['file1'])
    if file1.endswith('.bz2'):
        file1 = file1[:-4] + '.gz'
    file2 = os.path.join(readgroup['prefix'], readgroup['file2'])
    if file2.endswith('.bz2'):
        file2 = file2[:-4] + '.gz'
    return [file1, file2]

# cut adapters from inout
# DRAGMAP doesn;t work well with uBAM, so use fq as input
rule adapter_removal:
    input:
        get_fastqpaired
    output:
        for_f=os.path.join(config['FQ'], "{sample}.{readgroup}.cut_1.fq.gz"),
        rev_f=os.path.join(config['FQ'], "{sample}.{readgroup}.cut_2.fq.gz")
    # log file in this case contain some stats about removed seqs
    log:
        adapter_removal= os.path.join(config['STAT'], "{sample}.{readgroup}.adapter_removal.log"),
    benchmark:
        os.path.join(config['BENCH'], "{sample}.{readgroup}.adapter_removal.txt")
    priority: 10
    conda: "envs/preprocess.yaml"
    threads: config["adapter_removal"]["n"]
    shell: """
		AdapterRemoval --adapter1 AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT --file1 {input[0]} --file2 {input[1]} --gzip --gzip-level 1 --output1 {output.for_f} --output2 {output.rev_f} --settings {log.adapter_removal} --minlength 40  --threads {threads} 
		"""

rule adapter_removal_identify:
    input:
        get_fastqpaired
    output:
        stats=os.path.join(config['STAT'], "{sample}.{readgroup}.adapters"),
    priority: 10
    conda: "envs/preprocess.yaml"
    threads: config["adapter_removal_identify"]["n"]
    shell: """
		AdapterRemoval --identify-adapters --adapter1 AGATCGGAAGAGCACACGTCTGAACTCCAGTCA --adapter2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT --file1 {input[0]} --file2 {input[1]}  --threads {threads} > {output.stats}
		"""


def get_readgroup_params(wildcards):
    res = [rg for rg in SAMPLEINFO[wildcards['sample']]['readgroups'] if rg['info']['ID'] == wildcards['readgroup']][0]['info']
    
    return {'ID':res['ID'], 'LB':res.get('LB','unknown'), 'PL':res.get('PL','unknown'), 'PU':res.get('PU','unknown'), \
            'CN':res.get('CN','unknown'), 'DT':res.get('DT','unknown')}

# rule to align reads from cutted fq on hg38 ref
# use dragmap aligner
# samtools fixmate for future step with samtools mark duplicates

def get_mem_mb_align_reads(wildcrads, attempt):
    return attempt*int(config['align_reads']['mem'])

rule align_reads:
    input:
        for_f=rules.adapter_removal.output.for_f,
        rev_f=rules.adapter_removal.output.rev_f
    output:
        bam=os.path.join(config['BAM'],"{sample}.{readgroup}.aligned.bam")
    params:
        ref_dir = os.path.join(config['RES'], config['ref_dir']),
        # mask bed for current reference genome
        mask_bed = os.path.join(config['RES'], config['mask_bed']),
        temp_sort = os.path.join("sort_temporary_{sample}_{readgroup}"),
    conda: "envs/preprocess.yaml"
    threads: config["align_reads"]["n"]
    log:
        dragmap_log=os.path.join(config['LOG'], "{sample}.{readgroup}.dragmap.log"),
    benchmark:
        os.path.join(config['BENCH'], "{sample}.{readgroup}.dragmap.txt")
    priority: 15
    resources:
        mem_mb = get_mem_mb_align_reads
    shell:
        "dragen-os -r {params.ref_dir} -1 {input.for_f} -2 {input.rev_f} --RGID {wildcards.readgroup} --RGSM {wildcards.sample}  --ht-mask-bed {params.mask_bed} --num-threads {threads} 2> {log.dragmap_log} | samtools view -@ {threads} -o {output.bam}" 
        #--preserve-map-align-order 1 was tested, so that unaligned and aligned bam have sam read order (requires thread synchronization). But reduces performance by 1/3.  Better to let mergebam job deal with the issue.

rule merge_bam_alignment:
    input:
        get_fastqpaired,
        rules.align_reads.output.bam
    output:
        bam=os.path.join(config['BAM'],"{sample}.{readgroup}.merged.bam"),
        stats=os.path.join(config['STAT'],"{sample}.{readgroup}.merge_stats.tsv")
    conda: "envs/pypy.yaml"
    threads: config["merge_bam_alignment"]["n"]
    benchmark:
        os.path.join(config['BENCH'], "{sample}.{readgroup}.mergebam.txt")
    params:
        bam_merge=srcdir(config['BAMMERGE'])
    priority: 15
    shell:
       """
		samtools view -h --threads 4 {input[2]} | \
		pypy {params.bam_merge} -a  {input[0]} -b {input[1]} -s {output.stats}  |\
	    samtools view --threads 4 -o {output.bam}
	   """

rule sort_bam_alignment:
    input:
        in_bam = rules.merge_bam_alignment.output.bam
    output:
        bam=os.path.join(config['BAM'],"{sample}.{readgroup}.sorted.bam")
    params:
        # mask bed for current reference genome
        temp_sort = os.path.join("sort_temporary_{sample}_{readgroup}")
    conda: "envs/preprocess.yaml"
    threads: config["sort_bam_alignment"]["n"]
    log:
        samtools_fixmate=os.path.join(config['LOG'], "{sample}.{readgroup}.samtools_fixmate.log"),
        samtools_sort=os.path.join(config['LOG'], "{sample}.{readgroup}.samtools_sort.log"),
        samtools_index = os.path.join(config['LOG'], "{sample}.{readgroup}.samtools_index.log")
    benchmark:
        os.path.join(config['BENCH'], "{sample}.{readgroup}.sort.txt")
    priority: 15
    resources:
        tmpdir=tmpdir
    shell:
        """
            samtools fixmate -@ {threads} -u -O SAM  -m {input.in_bam} -  2> {log.samtools_fixmate} |\
            samtools sort -T {resources.tmpdir}/{params.temp_sort} -@ {threads} -l 1 -m 2000M -o {output.bam} 2> {log.samtools_sort} && \
            samtools index -@ {threads} {output.bam} 2> {log.samtools_index}
        """



# # function to get information about reaadgroups
# # needed if sample contain more than 1 fastq files
def get_readgroups_bam(wildcards):
    readgroups_b = SAMPLEINFO[wildcards['sample']]['readgroups']
    files = []
    for readgroup in readgroups_b:
        files.append(os.path.join(config['BAM'],  wildcards['sample'] + '.' + readgroup['info']['ID'] + '.sorted.bam'))
    return files

# merge different readgroups bam files for same sample
rule merge_rgs:
    input:
        get_readgroups_bam
    output:
        mer_bam = os.path.join(config['BAM'],  "{sample}.merged.bam")
    log: os.path.join(config['LOG'], "{sample}.mergereadgroups.log")
    benchmark: "benchmark/{sample}.merge_rgs.txt"
    threads: config['merge_rgs']['n']
    run: 
        if len(input) > 1:
            cmd = "samtools merge -@ {threads} {output} {input} 2> {log}"
            shell(cmd,conda_env='envs/preprocess.yaml')
        else:
            cmd = "ln {input} {output}"
            shell(cmd)

    # run:
    #     inputs = ' '.join(f for f in input if f.endswith('.bam'))
    #     shell("{samtools} merge -@ {threads} -o {output} {inputs} 2> {log}")

rule markdup:
    input:
        rules.merge_rgs.output.mer_bam
    output:
        mdbams = os.path.join(config['BAM'], "{sample}.markdup.bam"),
        MD_stat = os.path.join(config['STAT'], "{sample}.markdup.stat")
    benchmark: "benchmark/{sample}.markdup.txt"
    params:
        machine = 2500 #change to function
    # 100 for HiSeq and 2500 for NovaSeq
    # if fastq header not in known machines?
    # if not Illumina?
    log:
        samtools_markdup = os.path.join(config['LOG'], "{sample}.markdup.log"),
        samtools_index_md = os.path.join(config['LOG'], "{sample}.markdup_index.log")
    threads: config['markdup']['n']
    conda: "envs/preprocess.yaml"
    shell:
        "samtools markdup -f {output.MD_stat} -S -d {params.machine} -@ {threads} {input} {output.mdbams} 2> {log.samtools_markdup} && "
        "samtools index -@ {threads} {output.mdbams} 2> {log.samtools_index_md}"


# checkpoint cause we ned to check supplemetary ratio
# if supp_ratio is too high run additional clean process
checkpoint bamstats_all:
    input:
        rules.markdup.output.mdbams
    output:
        All_stats = os.path.join(config['STAT'],  '{sample}.bam_all.tsv')
    threads: config['bamstats_all']['n']
    params: py_stats = srcdir(config['BAMSTATS'])
    conda: "envs/pypy.yaml"
    shell:
        "samtools view -s 0.05 -h {input} --threads {threads} | pypy {params.py_stats} stats > {output}"


# this rule triggers in case of high supp_ratio
# resort bam file before additional cleanup
rule resort_by_readname:
    input:
        rules.markdup.output.mdbams
    output: resort_bams = temp(os.path.join(config['BAM'], '{sample}_resort.bam'))
    params: temp_sort = "resort_temporary_{sample}"
    threads: config['resort_by_readname']['n']
    conda: "envs/preprocess.yaml"
    resources:
        tmpdir=tmpdir
    shell: "samtools sort -T {resources.tmpdir}/{params.temp_sort} -n -@ {threads} -o  {output} {input}"
# additional cleanup with custom script
rule declip:
    input:
        rules.resort_by_readname.output.resort_bams
    output: declip_bam = temp(os.path.join(config['BAM'], '{sample}_declip.bam'))
    threads: config['declip']['n']
    params: declip = srcdir(config['DECLIP'])
    conda: "envs/pypy.yaml"
    shell:
        "samtools view -s 0.05 -h {input} --threads {threads} | pypy {params.declip} > {output}"
# back to original sort order after cleanup
rule sort_back:
    input:
        rules.declip.output.declip_bam,
    output:
        ready_bams = os.path.join(config['BAM'], '{sample}.DeClipped.bam'),
        All_stats= os.path.join(config['STAT'],  '{sample}.bam_all.additional_cleanup.tsv')
    threads: config['sort_back']['n']
    params:
        py_stats= srcdir(config['BAMSTATS']),
        temp_sort = "resort_back_temporary_{sample}"
    conda: "envs/pypy.yaml"
    resources:
        tmpdir=tmpdir
    shell:
        "samtools sort -T {resources.tmpdir}/{params.temp_sort} -@ {threads} -o {output.ready_bams} {input} &&"
        "samtools index -@ {threads} {output.ready_bams} &&"
        "samtools view -s 0.05 -h {input} --threads {threads} | pypy {params.py_stats} stats > {output.All_stats}"

# mapped cram
rule mCRAM:
    input:
        rules.markdup.output.mdbams
    output:
        CRAM = os.path.join(config['CRAM'], "{sample}_mapped_hg38.cram")
    threads: config['mCRAM']['n']
    benchmark: os.path.join(config['BENCH'], '{sample}_mCRAM.txt')
    conda: "envs/preprocess.yaml"
    shell:
        "samtools view --cram -T {ref} -@ {threads} -o {output.CRAM} {input}"
