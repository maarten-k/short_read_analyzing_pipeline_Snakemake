configfile: srcdir("Snakefile.cluster.json")
configfile: srcdir("Snakefile.paths.yaml")
gatk = config['gatk']
samtools = config['samtools']
bcftools = config['bcftools']
dragmap = config['dragmap']
verifybamid2 = config['verifybamid2']

ref = config['RES'] + config['ref']

wildcard_constraints:
    sample="[\w\d_\-@]+",
    # readgroup="[\w\d_\-@]+",

from read_samples import *
from common import *
SAMPLE_FILES, SAMPLEFILE_TO_SAMPLES, SAMPLEINFO = load_samplefiles('.', config)

# extract all sample names from SAMPLEINFO dict to use it rule all
sample_names = SAMPLEINFO.keys()

module Aligner:
    snakefile: 'Aligner.smk'
    config: config

module gVCF:
    snakefile: 'gVCF.smk'
    config: config
# use rule * from gVCF

bins = config['RES'] + config['bin_file_ref']

rule DBImport_all:
    input:
        expand(["labels/done_p{chr_p}.{chr}.{samplefile}.txt"], zip, chr = main_chrs_db, chr_p = chr_p, samplefile = SAMPLE_FILES*853),
        # rules.gVCF_all.input,
        # expand("{chr}_gvcfs.list", chr = main_chrs)
    default_target: True

DBImethod = config.get("DBI_method", "new")
DBIpath = config.get("DBIpath", "genomicsdb_")
if DBImethod == "new":
    # if want to
    DBI_method_params = "--genomicsdb-workspace-path "
    path_to_dbi = "genomicsdb_"
elif DBImethod == "update" and len(DBIpath) != 1:
    DBI_method_params = "--genomicsdb-update-workspace-path "
    path_to_dbi = DBIpath
elif DBImethod == "update" and len(DBIpath) == 1:
    raise ValueError(
        "If you want to update existing DB please provide path to this DB in format 'DBIpath=/path/to/directory_with_DB-s/genomicsdb_'"
        "Don't provide {chr}.p{chr_p} part of path!"
    )
else:
    raise ValueError(
        "invalid option provided to 'DBImethod'; please choose either 'new' or 'update'."
    )

# def get_parts_capture_kit(wildcards):
#     capture_kit = SAMPLEINFO[wildcards['sample']]['capture_kit']
#     chr = wildcards.chr
#     parts = wildcards.part
#     if SAMPLEINFO[wildcards['sample']]['sample_type'].startswith('illumina_wgs'):
#         capture_kit_chr_path = config['RES'] + config['kit_folder'] + config['MERGED_CAPTURE_KIT'] + '_hg38/' + config['MERGED_CAPTURE_KIT'] + '_hg38_' + chr + '.interval_list'
#     else:
#         capture_kit_parts_path = config['RES'] + config['kit_folder'] + capture_kit, 'interval_list', capture_kit + chr + parts + '.interval_list'
#     return capture_kit_parts_path

# def get_parts_capture_kit(wildcards):
#     chr = wildcards.chr
#     parts = wildcards.chr_p
#     capture_kit_parts_path = os.path.join(config['RES'], config['kit_folder'], config['MERGED_CAPTURE_KIT'], 'interval_list', config['MERGED_CAPTURE_KIT'] + '_' + chr + '_' + parts + '.interval_list')
#     return capture_kit_parts_path


rule backup_gdbi:
    input: gdbi = path_to_dbi + '{chr}.p{chr_p}'
    output: label = touch('labels/done_backup_{samplefile}_{chr}.p{chr_p}')
    params: tar = "{samplefile}_gdbi_{chr}.p{chr_p}.tar.gz"
    shell: """
            mkdir -p BACKUPS/previous &&
            find . -maxdepth 2 -name '*_gdbi_{chr}.p{chr_p}.tar.gz' -type f -print0 | xargs -0r mv -t BACKUPS/previous/ && 
            tar -czv -f BACKUPS/{params.tar} {input}
            """

if DBImethod == 'new':
    labels = []
elif DBImethod == 'update':
    labels = rules.backup_gdbi.output

def get_mem_mb_GenomicDBI(wildcrads, attempt):
    return attempt*(config['GenomicDBImport']['mem'])


rule GenomicDBImport:
    input:
        g=expand("{gvcfs}/reblock/{chr}/{sample}.{chr}.g.vcf.gz",gvcfs=config['gVCF'],sample=sample_names,allow_missing=True),
        intervals=os.path.join(config['RES'],config['kit_folder'],'BINS','interval_list','{chr}_{chr_p}.interval_list'),
        labels = labels
    log: config['LOG'] + "/GenomicDBImport.{samplefile}.{chr_p}.{chr}.log"
    benchmark: config['BENCH'] + "/{chr}_{chr_p}_{samplefile}_GenomicDBImport.txt"
    conda: "envs/preprocess.yaml"
    output:
        ready=touch('labels/done_p{chr_p}.{chr}.{samplefile}.txt')
    threads: config['GenomicDBImport']['n']
    params:
        inputs=expand(" -V {gvcfs}/reblock/{chr}/{sample}.{chr}.g.vcf.gz",gvcfs=config['gVCF'],sample=sample_names,allow_missing=True),
        dbi=os.path.join(path_to_dbi + "{chr}.p{chr_p}"),
        method=DBI_method_params,
        batches='75',
    priority: 30
    resources: mem_mb = get_mem_mb_GenomicDBI
    shell:
        """{gatk} GenomicsDBImport --java-options "-Xmx{resources.mem_mb}M"  --reader-threads {threads} {params.inputs} \
            --intervals {input.intervals}  -R {ref} {params.method} {params.dbi}/ --batch-size {params.batches} \
         --genomicsdb-shared-posixfs-optimizations true --bypass-feature-reader 2> {log}"""


