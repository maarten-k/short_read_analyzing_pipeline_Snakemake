import utils
import yaml

from constants import *
from read_samples import *


chr = ['chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10', 'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 'chr19', 'chr20', 'chr21', 'chr22', 'chrX', 'chrY']
main_chrs = ['chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10', 'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 'chr19', 'chr20', 'chr21', 'chr22', 'chrX', 'chrY']
main_chrs_ploidy_male = ['chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10', 'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 'chr19', 'chr20', 'chr21', 'chr22', 'chrX', 'chrY', 'chrXH','chrYH']
main_chrs_ploidy_female = ['chr1', 'chr2', 'chr3', 'chr4', 'chr5', 'chr6', 'chr7', 'chr8', 'chr9', 'chr10', 'chr11', 'chr12', 'chr13', 'chr14', 'chr15', 'chr16', 'chr17', 'chr18', 'chr19', 'chr20', 'chr21', 'chr22', 'chrX']


# Genome split levels (see Tools.smk). 

# 4 different components: A: autosomes + MT, X: X chromosome, Y: Y chromosome, F: full genome
# Autosomes have 5 different levels: 0: no split, 1: 10 splits, 2: 100 splits, 3: 1000 splits, 4: 10000 splits
# X and Y chromosome are split separately in 4 levels (levels: 0, 5, 50, 500 for X, 0, 2, 20, 200 for Y)
# full genome is not split (only level 0)

# 1. Split elements are 4-tuples of (component, level (nr. of digits), splitnr, ploidy)
# 2. A corresponding string region describer is generated from this tuple, e.g. ('A', 2, 3, 2) -> 'A23'
#    or ('X', 1, 3, 1) -> 'X3H' (see get_regions function below)
# 3. String region describers can be used to get the corresponding bed /interval_list files describing 
#    the region, e.g. A23 -> wes_bins/merged.autosplit2.03.bed or wgs_bins/genome.autosplit2.03.bed (see region_to_file function below)

# Note: The split files are not disjoint. The split files of a higher level
# are a subset of the split files of a lower level. E.g. genome.autosplit1.3.bed combines
# genome.autosplit2.30.bed to genome.autosplit2.39.bed, and genome.autosplit2.30.bed
# combines genome.autosplit3.300.bed to genome.autosplit3.399.bed.
# Function convert_to_level0 (see below) can be used to convert a region describer to a level 0 region describer.

# Note 2: exome and wgs splits are synced. That is
# merged.<component>split<level>.<splitnr>.bed is always the exome region within
# genome.<component>split<level>.<splitnr>.bed.
# Note also that due to this at higher levels the exome split files can sporadically be empty.
# also, exome levels only go to level 3 (for auto) and level 2 (for X and Y).

# Note 3: autosomes of level n are usually combined with sex chromosomes of level n-1. This is described
#         by the level0_range, level1_range, level2_range, level3_range etc. lists below.



level0_range = [('F', 0,0,2), ('X',0,0, 1), ('Y', 0,0, 1)]

level1_range = [('A', 1,x,2) for x in range(0,10)] + \
                [('X',0,0, 2), ('X', 0,0, 1),
                 ('Y',0,0, 2), ('Y', 0,0, 1)]

level2_range = [('A', 2,x,2) for x in range(0,100)] + \
               [('X', 1,x,2) for x in range(0,5)] + \
               [('X', 1, x, 1) for x in range(0, 5)] + \
               [('Y', 1, x,2) for x in range(0,2)] + \
               [('Y', 1, x, 1) for x in range(0, 2)] 

level3_range = [('A', 3, x,2) for x in range(0,1000)] + \
               [('X', 2, x,2) for x in range(0,50)] + \
               [('X', 2, x, 1) for x in range(0, 50)] + \
               [('Y', 2, x,2) for x in range(0,20)] + \
               [('Y', 2, x, 1) for x in range(0, 20)]               

level4_range = [('A', 4, x,2) for x in range(0,10000)] + \
                [('X', 3, x,2) for x in range(0,500)] + \
                [('X', 3, x, 1) for x in range(0, 500)] + \
                [('Y', 3, x,2) for x in range(0,200)] + \
                [('Y', 3, x, 1) for x in range(0, 200)]
              

def get_regions(lrange):
    """Converts a region describer (tuple format) to a list of regions (string format).
    E.g. [('A', 1, 3, 1), ('A', 1, 4, 2)] -> ['A03H', 'A04']
    """
    res = []
    
    for component, level,splitnr, ploidy in lrange:
        if ploidy == 1:
            ploidy = 'H'
        else:
            ploidy = ''
        if level == 0:
            region = f'{component}{ploidy}'
        else:
            region = f'{component}{splitnr:0{level}d}{ploidy}'
        res.append(region)
        
    return res

level0_regions = get_regions(level0_range)
level1_regions = get_regions(level1_range)
level2_regions = get_regions(level2_range)
level3_regions = get_regions(level3_range)
level4_regions = get_regions(level4_range)


def convert_to_level0(region):
    """Converts a region describer of level >=0 to the corresponding level 0 region.
    E.g. A33H -> A, X22H -> XH, X1 -> F
    """
    if region in level0_regions:
        return region
    if region.startswith('A') or region.startswith('F'):
        return 'F'
    elif region.startswith('X'):
        return 'F' if not region.endswith('H') else 'XH'
    elif region.startswith('Y'):
        return 'F' if not region.endswith('H') else 'YH'
    else:
        raise ValueError(f'Unknown region {region}')
    

def region_to_file(region, wgs=False, extension='bed'):
    """ Converts a region describer to the filename of the file describing the region.
    
        E.g. A33H, wgs=False, extension=bed -> <interval_folder>/wes_bins/merged.autosplit2.33.bed
        
        :param region: region describer
        :param wgs: whether to use the wgs or wes intervals
        :param extension: extension of the file (bed or interval_list)
    """
    
    component = region[0]
    if region.endswith('H'):
        region = region[:-1]

    split = region[1:]
    
    if component == 'A':
        component = 'auto'
    elif component == 'F':
        component = 'full'

    level = len(split)
    if level > 0:
        split = '.' + split
    else:
        split = ''
    if wgs: 
        f = pj(INTERVALS_DIR, f'wgs_bins/genome.{component}split{level}{split}.{extension}')     
    else:
        f = pj(INTERVALS_DIR, f'wes_bins/merged.{component}split{level}{split}.{extension}')        
    return f
    


# OLD REGIONS

chr_p = [str('0') + str(e) for e in range(0, 10)] + [str(i) for i in range(10, 90)] + [str(a) for a in range(9000, 9762)]
main_chrs_db = []
main_chrs_db.extend(['chr1']*84)
main_chrs_db.extend(['chr2']*66)
main_chrs_db.extend(['chr3']*51)
main_chrs_db.extend(['chr4']*36)
main_chrs_db.extend(['chr5']*40)
main_chrs_db.extend(['chr6']*42)
main_chrs_db.extend(['chr7']*43)
main_chrs_db.extend(['chr8']*30)
main_chrs_db.extend(['chr9']*35)
main_chrs_db.extend(['chr10']*37)
main_chrs_db.extend(['chr11']*45)
main_chrs_db.extend(['chr12']*47)
main_chrs_db.extend(['chr13']*16)
main_chrs_db.extend(['chr14']*27)
main_chrs_db.extend(['chr15']*32)
main_chrs_db.extend(['chr16']*36)
main_chrs_db.extend(['chr17']*45)
main_chrs_db.extend(['chr18']*14)
main_chrs_db.extend(['chr19']*44)
main_chrs_db.extend(['chr20']*21)
main_chrs_db.extend(['chr21']*10)
main_chrs_db.extend(['chr22']*19)
main_chrs_db.extend(['chrX']*30)
main_chrs_db.extend(['chrY']*3)

valid_chr_p = {'chr1': chr_p[:84],
               'chr2': chr_p[84:150],
               'chr3': chr_p[150:201],
               'chr4': chr_p[201:237],
               'chr5': chr_p[237:277],
               'chr6': chr_p[277:319],
               'chr7': chr_p[319:362],
               'chr8': chr_p[362:392],
               'chr9': chr_p[392:427],
               'chr10': chr_p[427:464],
               'chr11': chr_p[464:509],
               'chr12': chr_p[509:556],
               'chr13': chr_p[556:572],
               'chr14': chr_p[572:599],
               'chr15': chr_p[599:631],
               'chr16': chr_p[631:667],
               'chr17': chr_p[667:712],
               'chr18': chr_p[712:726],
               'chr19': chr_p[726:770],
               'chr20': chr_p[770:791],
               'chr21': chr_p[791:801],
               'chr22': chr_p[801:820],
               'chrX': chr_p[820:850],
               'chrY': chr_p[850:]}


def get_validated_sex_file(input):
    #this file should exist after running 'get_validated_sex' job.
    #it should also certainly exist after the bam file is created,
    #as it relies on this file.
    filename = input['validated_sex']
    with open(filename) as f:
        xsample = yaml.load(f,Loader=yaml.FullLoader)
    return 'male' if  xsample['sex'] == 'M' else 'female'

def get_ref_by_validated_sex(wildcards, input):
    sex = get_validated_sex_file(input)
    return REF_FEMALE if sex == 'female' else REF_MALE

def get_refdir_by_validated_sex(wildcards, input):
    sex = get_validated_sex_file(input)
    return REF_FEMALE_DIR if sex == 'female' else REF_MALE_DIR

def get_strref_by_validated_sex(wildcards, input):
    sex = get_validated_sex_file(input)
    return REF_FEMALE_STR if sex == 'female' else REF_MALE_STR

cache = {}
SAMPLE_FILES, SAMPLEFILE_TO_SAMPLES, SAMPLEINFO, SAMPLE_TO_BATCH, SAMPLEFILE_TO_BATCHES = load_samplefiles('.',cache)

# extract all sample names from SAMPLEINFO dict to use it rule all
sample_names = SAMPLEINFO.keys()