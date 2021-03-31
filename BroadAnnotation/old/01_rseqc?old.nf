



log.info "=============================================="
log.info " Merge stringtie assemblies and perform prediction "
log.info "=============================================="

// Directories
params.prefix_data = "/gpfs/projects/bsc83/Data"
params.output_dir = "${params.prefix_data}/Ebola/99_BroadAnnotation_Feb2021/"
params.output_dir_sub = "gene_annotations"

// SCRIPTS
gtf2bed = Channel.fromPath("${baseDir}/scripts/gtf2bed.R").collect()

// Annotation
params.reference_annotated = "/gpfs/projects/bsc83/Data/Ebola/00_RawData/BroadTranscriptomesComplete/stringtie2-gtfs-new/annotation.gtf"
annotation = Channel.fromPath("${params.reference_annotated}").collect()


// Bam files
bams = Channel.fromPath("/gpfs/projects/bsc83/Data/Ebola/00_RawData/BroadTranscriptomesComplete/bams-new/*")
                .ifEmpty("No bams found")
                .map { tuple(it.baseName, it) }



process gtf2bed{
   storeDir "${params.output_dir}/${output_dir_sub}/"

   input:
   file gtf2bed
   file annotation

   output:
   file("${annotation.baseName}.bed12") into bed_channel

   script:
   """
   Rscript ${gtf2bed} ${annotation} ${annotation.baseName}.bed12
   """
}


process runRSeQC{

  storeDir "${params.output_dir}/03b_rseqc/${complete_id}"

  input:

  set complete_id,
      file(bam) from bams
  file(bed12) from  bed_channel.collect()

  output:
  file "*" into read_distribution_channel

  script:
  """
  read_distribution.py -i ${bam} -r ${bed12} > ${complete_id}.UMI.f3.q60.read_distribution.txt
  infer_experiment.py -i ${bam} -r ${bed12} > ${complete_id}.infer_experiment.txt
  junction_annotation.py -i ${bam} -o ${complete_id}.rseqc -r ${bed12}
  bam_stat.py -i ${bam} > ${complete_id}.bam_stat.txt
  junction_saturation.py -i ${bam} -o ${complete_id}.rseqc -r ${bed12} > ${complete_id}.junction_annotation_log.txt
  inner_distance.py -i ${bam} -o ${complete_id}.rseqc -r ${bed12}
  read_duplication.py -i ${bam} -o ${complete_id}.read_duplication
  """
}
