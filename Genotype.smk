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
    readgroup="[\w\d_\-@]+",



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
module DBImport:
    snakefile: 'DBImport.smk'
    config: config
use rule * from DBImport

bins = config['RES'] + config['bin_file_ref']


rule Genotype_all:
    input:
        rules.DBImport_all.input,
        # expand(config['VCF'] + "/Merged_raw_DBI_{chr_p}.vcf.gz", chr_p = chr_p),
        expand("{vcf}/ALL_chrs.vcf.gz", vcf=config['VCF']),
        expand("{vcf}/Merged_norm.vcf", vcf=config['VCF_Final']),
    default_target: True


DBImethod = config.get("DBI_method", "new")
# genotype
# multiple samplefiles
if DBImethod == "new":
    rule GenotypeDBI:
        input:
            dir = rules.GenomicDBImport.params.dbi,
            test = rules.GenomicDBImport.output.ready
        output:
            raw_vcfDBI=config['VCF'] + "/Merged_raw_DBI_{chr}.p{chr_p}.vcf.gz"
        log: config['LOG'] + '/' + "GenotypeDBI_{chr}.p{chr_p}.log"
        benchmark: config['BENCH'] + "/GenotypeDBI_{chr}.p{chr_p}.txt"
        params:
            dbsnp = config['RES'] + config['dbsnp'],
            intervals= config['RES'] + config['bin_file_ref'] + '/{chr}/hg38_mainchr_bins{chr_p}.bed.interval_list'
        conda: "envs/preprocess.yaml"
        priority: 40
        shell:
                "{gatk} GenotypeGVCFs -R {ref} -V gendb://{input.dir} -O {output} -D {params.dbsnp} --intervals {params.intervals} 2> {log}"
elif DBImethod == "update":
    rule GenotypeDBI:
        input:
            gvcf = rules.SelectVariants_For_Genotype.output.gvcf,
            test = rules.GenomicDBImport.output.ready
        output:
            raw_vcfDBI=config['VCF'] + "/Merged_raw_DBI_{chr}.p{chr_p}.vcf.gz"
        log: config['LOG'] + '/' + "GenotypeDBI_{chr}.p{chr_p}.log"
        benchmark: config['BENCH'] + "/GenotypeDBI_{chr}.p{chr_p}.txt"
        params:
            dbsnp = config['RES'] + config['dbsnp'],
            intervals= config['RES'] + config['bin_file_ref'] + '/{chr}/hg38_mainchr_bins{chr_p}.bed.interval_list'
        conda: "envs/preprocess.yaml"
        priority: 40
        shell:
                "{gatk} GenotypeGVCFs -R {ref} -V {input.gvcf} -O {output} -D {params.dbsnp} --intervals {params.intervals} 2> {log}"
else:
    raise ValueError(
        "invalid option provided to 'DBImethod'; please choose either 'new' or 'update'."
    )

rule Mergechrs:
    input:
        expand(["{dir}/Merged_raw_DBI_{chr}.p{chr_p}.vcf.gz"],zip,chr=main_chrs_db,chr_p=chr_p, dir = [config['VCF']]*99)
    params:
        vcfs = expand(["-I {dir}/Merged_raw_DBI_{chr}.p{chr_p}.vcf.gz"],zip,chr=main_chrs_db,chr_p=chr_p, dir = [config['VCF']]*99)
    conda: "envs/preprocess.yaml"
    log: config['LOG'] + '/' + "Mergechrs.log"
    benchmark: config['BENCH'] + "/Mergechrs.txt"
    output:
        vcf = config['VCF'] + "/ALL_chrs.vcf.gz"
    priority: 45
    shell:
        "{gatk} GatherVcfs {params.vcfs} -O {output} -R {ref} 2> {log} && {gatk} IndexFeatureFile -I {output} "

rule norm:
    input:
        rules.Mergechrs.output.vcf
    output:
        normVCF=config['VCF_Final'] + "/Merged_norm.vcf",
        idx=config['VCF_Final'] + "/Merged_norm.vcf.idx"
    log: config['LOG'] + '/' + "normalization.log"
    benchmark: config['BENCH'] + "/normalization.txt"
    priority: 80
    conda: "envs/preprocess.yaml"
    shell:
        "{bcftools} norm -f {ref} {input} -m -both -O v | {bcftools} norm -d exact -f {ref} > {output.normVCF} 2> {log} && {gatk} IndexFeatureFile -I {output.normVCF} -O {output.idx} "

