#  ------------------  Utils


iterate_files <- function(inpath, pattern_string){
  files <- list.files(path=inpath, pattern= pattern_string, full.names=TRUE, recursive=TRUE)
  return(files)
}

extract_info_sample_from_filename <- function(file){
  file_no_ext <- strsplit(file,".", fixed = T)[[1]][1]
  info <- strsplit(tail(strsplit(file_no_ext,"/", fixed = T)[[1]],1),"_", fixed = T)[[1]]
  dataset <- info[1]
  tissue <- info[2]
  dpo <- info[3]
  sample <- info[4]
  sample_name=paste(dataset,tissue,dpo,sample,sep="_")
  return(c(dataset,tissue,dpo,sample, sample_name))
}

extract_se <- function(ctabs){
  coldata = extract_coldata(ctabs)
  print(ctabs)
  # get tx2gene table
  tx2gene <- read_tsv(ctabs[1])[, c("t_name","gene_id", "gene_name")]
  rowdata = tx2gene
  tx2gene = rowdata[,1:2]
  # Import tx
  txi <- tximport(ctabs, type = "stringtie", tx2gene = tx2gene, txOut = TRUE)
  rownames(coldata) = coldata[["completeid"]]
  rowdata = rowdata[match(rownames(txi[[1]]), as.character(rowdata[["t_name"]])),]
  rownames(rowdata) = rowdata[["t_name"]]
  # Create summarized experiment
  se = SummarizedExperiment(assays = list(counts = txi[["counts"]],
                                          abundance = txi[["abundance"]],
                                          length = txi[["length"]]),
                            colData = coldata,
                            rowData = rowdata)
  # Create summarized experiment at gene level
  if (!is.null(tx2gene)){
    gi = summarizeToGene(txi, tx2gene = tx2gene)
    growdata = unique(rowdata[,2:3])
    growdata = growdata[match(rownames(gi[[1]]), growdata[["gene_id"]]),]
    rownames(growdata) = growdata[["tx"]]
    gse = SummarizedExperiment(assays = list(counts = gi[["counts"]],
                                             abundance = gi[["abundance"]],
                                             length = gi[["length"]]),
                               colData = DataFrame(coldata),
                               rowData = growdata)
  }
  return(se)
}


# ----- UTILS ---------------
vd_draw <- function(list,c_names =  c("Ref" , "FeelNC" )){

  if(length(list) > 2){
    myCol <- brewer.pal(length(list), "Pastel2")
  }else{
    myCol <-  c("#B3E2CD","#FDCDAC")
  }
  temp <- venn.diagram(
    x = list,
    category.names = c_names,
    filename = NULL,
    output=TRUE,

    # Circles
    lwd = 2,
    lty = 'blank',
    fill = myCol,

    # Numbers
    cex = .7,
    fontface = "bold",
    fontfamily = "sans"

  )
  grid.draw(temp)
}

# Samples coldata
extract_coldata <- function(files){
  samples <- data.frame(dataset=character(),
                        tissue=character(),
                        dpo=character(),
                        sample=character(),
                        method=character(),
                        completeid=character(),
                        stringsAsFactors=FALSE)
  for (file in files){
    row <- c(dataset,tissue,dpo,sample,completeid, method)%<-%get_info_from_file_path(file)
    samples <- samples %>% add_row(dataset = dataset, tissue = tissue, dpo = dpo, sample=sample, completeid = completeid, method = method)
  }
  rownames(samples) <- samples$completeid
  return(samples)
}


get_colData <- function(matrix){
  samples <- data.frame(dataset=character(),
                        tissue=character(),
                        dpo=character(),
                        sample=character(),
                        completeid=character(),
                        stringsAsFactors=FALSE)
  for (file in colnames(matrix)){
    infos = strsplit(file, "_")
    index = 1
    dataset =  infos[[1]][index]
    tissue = infos[[1]][index + 1]
    dpo = infos[[1]][index + 2]
    sample = infos[[1]][index + 3]
    completeid=paste(dataset,tissue,dpo,sample,sep="_")
    samples <- samples %>% add_row(dataset = dataset, tissue = tissue, dpo = dpo, sample=sample, completeid = completeid)
  }
  rownames(samples) <- samples$completeid
  return(samples)
}

extract_info_sample_from_dir <- function(file){
  file_no_ext <- strsplit(file,".", fixed = T)[[1]][1]
  info <- rev(strsplit(file, "/")[[1]])
  dataset <- info[5]
  tissue <- info[4]
  dpo <- info[3]
  sample <- info[2]
  sample_name=paste(dataset,tissue,dpo,sample,sep="_")
  return(c(dataset,tissue,dpo,sample, sample_name))
}


get_info_from_file_path <- function(file){
  infos = strsplit( dirname(file), "/")
  index = length(infos[[1]]) - 4
  dataset =  infos[[1]][index]
  tissue = infos[[1]][index + 1]
  dpo = infos[[1]][index + 2]
  sample = infos[[1]][index + 3]
  method = infos[[1]][index + 4]
  sample_name=paste(dataset,tissue,dpo,sample,sep="_")
  return(c(dataset,tissue,dpo,sample,sample_name,method))
}
get_filename <- function(file){
  return(tail(strsplit(file,"/", fixed = T)[[1]],1))
}

# Only for htseq counts
get_filename_and_dirs <- function(file){
  infos %<-% extract_info_sample_from_filename(file)
  file_path = paste(infos[c(1:4)],collapse="/")
  filename <- get_filename(file)
  file_path = paste(file_path, "htseq_counts", sep ="/")
  file_path = paste(file_path, filename, sep ="/")
  return(file_path)
}


create_dds <- function(sampleFiles,directory, names_from_dir = FALSE, tximport = FALSE, tx_obj =NA){

  if(names_from_dir){
    samples_info <- sapply(sampleFiles,extract_info_sample_from_dir)
  }else{
    samples_info <- sapply(sampleFiles,extract_info_sample_from_filename)
  }
  # Create ddsHTSeq Object
  sampleTable <- data.frame(sampleName = sampleFiles,
                            fileName = sapply(sampleFiles,get_filename_and_dirs),
                            condition = samples_info[1,],
                            tissue = samples_info[2,],
                            dpo = samples_info[3,],
                            id = samples_info[4,],
                            complete_id = samples_info[5,]
  )
  if(tximport){
    print("UsingTXimport")
    dds <- DESeqDataSetFromTximport(tx_obj,sampleTable,
                                      ~ 1)

  }else{
    dds <- DESeqDataSetFromHTSeqCount(sampleTable = sampleTable,
                                      directory = directory,
                                      design= ~ 1)
  }


  return(dds)
}


