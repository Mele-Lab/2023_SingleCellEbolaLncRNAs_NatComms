
# ------------------------------------------------
#  Utils for lncRNA annotation stats
# ------------------------------------------------

# Given a genomic range gets only the maximum transcript of a gene
# computed based on the sum of the lenghts of its exons.
get_only_max_transcript <- function(gr){
  df <- data.frame("gene_id" = gr$gene_id,"transcript_id" = gr$transcript_id, "range_width" = width(ranges(gr)))
  gene_with_multiple_isoforms <-df[!duplicated(df$transcript_id),] %>% dplyr::group_by(gene_id) %>% dplyr::summarize(number=dplyr::n()) %>% dplyr::filter(number > 1)
  collapsed <-df %>% dplyr::group_by(gene_id,transcript_id) %>% dplyr::summarize("range" = sum(range_width)) %>% dplyr::group_by(gene_id) %>% dplyr::slice(which.max(range))
  gene_with_one_isoform <-df[!duplicated(df$transcript_id),] %>% dplyr::group_by(gene_id) %>% dplyr::summarize(number=dplyr::n()) %>% dplyr::filter(number == 1) 
  gr <- gr[gr$transcript_id %in% collapsed$transcript_id ,]
  return(gr)
}

# Obtain number of exons per gene
get_nr_exons <- function(gr){
  df <- data.frame("gene_id" = gr$gene_id,"exon_number" = as.numeric(gr$exon_number))
  number_exons <- df %>% dplyr::group_by(gene_id) %>%dplyr::summarize(max_exon = max(exon_number))
  return(number_exons)
}


add_type <- function(mean_expression, ids, name){
  mask <- mean_expression$id %in% ids
  mean_expression[mask,]$type <- name
  return(mean_expression)
}

# Barplot of the number of exons for novel lncRNAs 
barplot_exon_count <- function(gr, type, col){
  ## extract the number of exons
  gr <- gr[gr$type =="exon",]
  gr <- get_only_max_transcript(gr)
  df_l <- data.frame(get_nr_exons(gr))
  df_l$type <- type
  
  h <- ggplot(df_l, aes(x=max_exon, fill=type)) + 
    geom_histogram(position="identity", binwidth =1)+
    xlim(1,15)
  
  h_plotdata <- ggplot_build(h)$data[[1]]
  h_plotdata$group <- as.factor(h_plotdata$group)
  levels(h_plotdata$group) <- c(type)
  
  ## plot with geom_bar
  p1 <-ggplot(h_plotdata, aes(x=x, y=y, fill = group, palette = col )) +
    geom_bar(stat = "identity", width = 0.8) +
    theme(legend.title=element_blank())+
    labs(y = "", x = "")+
    theme(legend.title=element_blank())+ theme(legend.position = "none")+
    scale_x_continuous( labels = as.character(h_plotdata$x), breaks = (h_plotdata$x)) + 
    theme(plot.title = element_text(hjust = 0.5), axis.text = element_text(size =15))+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    scale_fill_manual(values=c(col))+scale_y_continuous(expand = c(0,1),breaks = c(round_any(max(h_plotdata$y), 100, f = floor)))

  return(p1)
}


# Obtain length of the exon 
calc_exon_length <- function(gr, type){
  gr <- gr[gr$type =="exon",]
  gr <- get_only_max_transcript(gr)
  df <- data.frame("gene_id" = gr$gene_id,"transcript_id" = gr$transcript_id, "exon_number" = gr$exon_number, "range_width" = width(ranges(gr)))
  collapsed <- df%>% dplyr::group_by(gene_id,transcript_id, exon_number) %>% dplyr::summarize("range" = sum(range_width))
  collapsed["type"] <- type
  return(collapsed)
}

# Obtain length of the transcript 
calc_transcript_length <- function(gr, type){
  gr <- gr[gr$type =="exon",]
  gr <- get_only_max_transcript(gr)
  df <- data.frame("gene_id" = gr$gene_id,"transcript_id" = gr$transcript_id, "range_width" = width(ranges(gr)))
  collapsed <- df%>% dplyr::group_by(gene_id,transcript_id) %>% dplyr::summarize("range" = sum(range_width))
  collapsed["type"] <- type
  return(collapsed)
}

# deplete all monoexonic transcripts 
remove_one_exon <- function(gr){
  df_l <- data.frame(get_nr_exons(gr[gr$type =="exon",]))
  depleted <- gr[gr$gene_id %in% df_l[df_l$max_exon > 1,]$gene_id,]
  return(depleted)
}

# Boxplot of expression
plot_expression <- function(max_expression, palette_expression = palette_expression, level=  c("Novel lncRNAs","Annotated lncRNAs", "mRNAs")){
  plot <- ggplot(max_expression, aes(x=factor(type,level = level) , y=expr, fill = factor(type,level = level), colour = factor(type,level = level) )) + 
    geom_boxplot(alpha = 0.6 )+
    scale_fill_manual(values =palette_expression)+
    scale_color_manual(values = palette_expression)+
    labs(y = "logFPKM", x = "", title = "Maximum Expression" )+
    theme(legend.title=element_blank())+
    theme(plot.title = element_text(hjust = 0.5))+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    theme(panel.background = element_rect(fill = "white", colour = "grey50"))+theme(legend.position = "none")
  return(plot)
}

plot_stats_annotation <- function (novel_expressed,lncRNAs_ref,lncRNAs_ref_human, mrna_ref_human, mRNAs_ref,df, palette = c("#E8C2D8", "#D4549C", "#900051", "#8195D7", "navy")){

  levels <- c('Novel LncRNAs', 'Annotated LncRNAs - Macaque ', 'Annotated LncRNAs - Human',"Annotated mRNAs - Macaque", "Annotated mRNAs - Human" )
  # --------------------
  ## EXON COUNT
  # --------------------
  
  ec1 <- barplot_exon_count(novel_expressed, "Novel", palette[1])+
                    theme(axis.ticks.x = element_blank(),
                          axis.text.x = element_blank(),
                          axis.line.x = element_blank())
  ec2 <- barplot_exon_count(lncRNAs_ref, "lncRNAs - Reference Macaque", palette[2])+
                      theme(axis.ticks.x = element_blank(),
                            axis.text.x = element_blank(),
                            axis.line.x = element_blank())
  ec3 <- barplot_exon_count(lncRNAs_ref_human, "lncRNAs - Reference Human", palette[3])+
                        theme(axis.ticks.x = element_blank(),
                              axis.text.x = element_blank(),
                              axis.line.x = element_blank())
  ec4 <- barplot_exon_count(mrna_ref_human, "mRNAs - Reference Human", palette[4])+
                  theme(axis.ticks.x = element_blank(),
                        axis.text.x = element_blank(),
                        axis.line.x = element_blank())
  ec5 <- barplot_exon_count(mRNAs_ref, "mRNAs - Reference Macaque", palette[5])
                      
  a <- ggarrange( ec1,ec2,ec3,ec4,ec5,  ncol=1, nrow=5, heights = c(1,1,1,1,1.5)) 
  a <- annotate_figure(a, bottom = text_grob("Number of Exons", size  = 22), left = text_grob("Frequency", size = 22, rot = 90))

  
  # --------------------
  ## Transcript lengths - Boxplot
  # --------------------
  df <- data.frame()
  df <- rbind(df,data.frame(calc_transcript_length(novel_expressed, "Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_transcript_length(lncRNAs_ref, "Annotated LncRNAs - Macaque ")))
  df <- rbind(df,data.frame(calc_transcript_length(lncRNAs_ref_human, "Annotated LncRNAs - Human")))
  df <- rbind(df,data.frame(calc_transcript_length(mrna_ref_human, "Annotated mRNAs - Human")))
  df <- rbind(df,data.frame(calc_transcript_length(mRNAs_ref, "Annotated mRNAs - Macaque")))
  
  p <- ggplot(df, aes(x = factor(type, level = levels),  y = range )) +
    labs( x = "", y = "Transcript Length" , title = "Transcript length")+
    theme(axis.text.x = element_blank(), plot.title = element_text(size = 26),axis.text.y = element_text(size = 20), axis.title = element_text(size = 20))+
    geom_boxplot(outlier.shape=NA, fill = palette,color = palette, alpha = 0.6, na.rm = TRUE) + ylim(0,10000)+
    theme(legend.title=element_blank(), legend.position = "top")+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    theme(plot.title = element_text(hjust = 0.5))+
    theme(panel.background = element_rect(fill = "white", colour = "grey50"))+
    scale_y_continuous(limits = quantile(df$range, c(0.1,0.9)))

  
  # --------------------
  ## Exon lengths - Boxplot
  # --------------------
  df <- data.frame()
  df <- rbind(df,data.frame(calc_exon_length(novel_expressed, "Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_exon_length(lncRNAs_ref, "Annotated LncRNAs - Macaque ")))
  df <- rbind(df,data.frame(calc_exon_length(lncRNAs_ref_human, "Annotated LncRNAs - Human")))
  df <- rbind(df,data.frame(calc_exon_length(mrna_ref_human, "Annotated mRNAs - Human")))
  df <- rbind(df,data.frame(calc_exon_length(mRNAs_ref, "Annotated mRNAs - Macaque")))
  
  p1 <- ggplot(df, aes(x = factor(type, level = levels),  y = range )) +
    labs( x = "", y = "Exon Length" , title = "Exon length")+
    theme(axis.text.x = element_blank(), plot.title = element_text(size = 26),axis.text.y = element_text(size = 20), axis.title = element_text(size = 20))+
    geom_boxplot(outlier.shape= NA, notch = FALSE, fill = palette,color = palette, alpha = 0.6, na.rm = TRUE)+
    theme(legend.title=element_blank())+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    theme(plot.title = element_text(hjust = 0.5))+
    theme(panel.background = element_rect(fill = "white", colour = "grey50"))+
    scale_y_continuous(limits = quantile(df$range, c(0.1,0.9)))

  return(list(a,p,p1))
}

plot_stats_annotation_separated <- function (novel_expressed_poly, novel_expressed_ribo,lncRNAs_ref,lncRNAs_ref_human, mrna_ref_human, mRNAs_ref,df){
  palette <-brewer.pal(5,"Paired")
  palette <- c("#F4E3ED", "#E9A3C9", "#C51B7D", "#E6F5D0", "#A1D76A")
  palette <- c("blue", "purple", "#D4549C", "#900051", "#A1D76A", "#308B1E")
  #palette <- c("#FF817C","#FF0000", "#A70000", "#AFD2FF", "#040AAF")
  palette <- c("orange","#994C00", "#D4549C", "#900051", "#8195D7", "navy")
  levels <- c('Poly(A) Novel LncRNAs', 'Ribodepleted Novel LncRNAs', 'Annotated LncRNAs - Macaque ', 'Annotated LncRNAs - Human',"Annotated mRNAs - Macaque", "Annotated mRNAs - Human" )
  # --------------------
  ## EXON COUNT
  # --------------------
  
  ec1 <- barplot_exon_count(novel_expressed_poly, "Poly(A) Novel LncRNAs", palette[1])+
    theme(axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.line.x = element_blank())
  ec1b <- barplot_exon_count(novel_expressed_ribo, "Ribodepleted Novel LncRNAs", palette[2])+
    theme(axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.line.x = element_blank())
  ec2 <- barplot_exon_count(lncRNAs_ref, "lncRNAs - Reference Macaque", palette[3])+
    theme(axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.line.x = element_blank())
  ec3 <- barplot_exon_count(lncRNAs_ref_human, "lncRNAs - Reference Human", palette[4])+
    theme(axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.line.x = element_blank())
  ec4 <- barplot_exon_count(mrna_ref_human, "mRNAs - Reference Human", palette[5])+
    theme(axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.line.x = element_blank())
  ec5 <- barplot_exon_count(mRNAs_ref, "mRNAs - Reference Macaque", palette[6])
  
  a <- ggarrange( ec1, ec1b,ec2,ec3,ec4,ec5,  ncol=1, nrow=6, heights = c(1,1,1,1,1, 1.5)) 
  a <- annotate_figure(a, bottom = text_grob("Number of Exons", size  = 22), left = text_grob("Frequency", size = 22, rot = 90))
  
  # Exon count generally lower in lncrnas than mrnas (Ok. same as sources)

  
  
  # --------------------
  ## Transcript lengths - Boxplot
  # --------------------
  df <- data.frame()
  df <- rbind(df,data.frame(calc_transcript_length(novel_expressed_poly, "Poly(A) Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_transcript_length(novel_expressed_ribo, "Ribodepleted Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_transcript_length(lncRNAs_ref, "Annotated LncRNAs - Macaque ")))
  df <- rbind(df,data.frame(calc_transcript_length(lncRNAs_ref_human, "Annotated LncRNAs - Human")))
  df <- rbind(df,data.frame(calc_transcript_length(mrna_ref_human, "Annotated mRNAs - Human")))
  df <- rbind(df,data.frame(calc_transcript_length(mRNAs_ref, "Annotated mRNAs - Macaque")))
  
  p <- ggplot(df, aes(x = factor(type, level = levels),  y = range )) +
    labs( x = "", y = "Transcript Length" , title = "Transcript length")+
    theme(axis.text.x = element_blank(), plot.title = element_text(size = 26),axis.text.y = element_text(size = 20), axis.title = element_text(size = 20))+
    geom_boxplot(outlier.shape=NA, fill = palette,color = palette, alpha = 0.6, na.rm = TRUE) + ylim(0,10000)+
    theme(legend.title=element_blank(), legend.position = "top")+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    theme(plot.title = element_text(hjust = 0.5))+
    theme(panel.background = element_rect(fill = "white", colour = "grey50"))+
    scale_y_continuous(limits = quantile(df$range, c(0.1,0.9)))
  
  # Just for having the palette 
  pal <- ggplot(df, aes(x = factor(type, level = levels),  y = range, fill =factor(type, level = levels), color = factor(type, level = levels) )) +
  geom_density()+scale_fill_manual(values = palette)+scale_color_manual(values = palette)
  
  
  
  # --------------------
  ## Exon lengths - Boxplot
  # --------------------
  df <- data.frame()
  df <- rbind(df,data.frame(calc_exon_length(novel_expressed_poly, "Poly(A) Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_exon_length(novel_expressed_ribo, "Ribodepleted Novel LncRNAs")))
  df <- rbind(df,data.frame(calc_exon_length(lncRNAs_ref, "Annotated LncRNAs - Macaque ")))
  df <- rbind(df,data.frame(calc_exon_length(lncRNAs_ref_human, "Annotated LncRNAs - Human")))
  df <- rbind(df,data.frame(calc_exon_length(mrna_ref_human, "Annotated mRNAs - Human")))
  df <- rbind(df,data.frame(calc_exon_length(mRNAs_ref, "Annotated mRNAs - Macaque")))
  
  p1 <- ggplot(df, aes(x = factor(type, level = levels),  y = range )) +
    labs( x = "", y = "Exon Length" , title = "Exon length")+
    theme(axis.text.x = element_blank(), plot.title = element_text(size = 26),axis.text.y = element_text(size = 20), axis.title = element_text(size = 20))+
    geom_boxplot(outlier.shape= NA, notch = FALSE, fill = palette,color = palette, alpha = 0.6, na.rm = TRUE)+
    theme(legend.title=element_blank())+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    theme(plot.title = element_text(hjust = 0.5))+
    theme(panel.background = element_rect(fill = "white", colour = "grey50"))+
    scale_y_continuous(limits = quantile(df$range, c(0.1,0.9)))
  
  return(list(a,p,p1, pal))
}

# Plot tissue specificity 
barplot_tissues <- function(df, type, col){
  ## extract the number of exons
  df_l <- df[df$type == type,]
  h <- ggplot(df_l, aes(x=n_tissues_expresseing_gene, fill=type)) + 
    geom_histogram(position="identity", binwidth =1)+
    xlim(1,16)
  
  h_plotdata <- ggplot_build(h)$data[[1]]
  h_plotdata$group <- as.factor(h_plotdata$group)
  levels(h_plotdata$group) <- c(type)
  
  ## plot with geom_bar
  p1 <-ggplot(h_plotdata, aes(x=x, y=y, fill = group, palette = col )) +
    geom_bar(stat = "identity", width = 0.8) +
    theme(legend.title=element_blank())+
    labs(y = "", x = "")+
    theme(legend.title=element_blank())+ theme(legend.position = "none")+
    scale_x_continuous( labels = as.character(h_plotdata$x), breaks = (h_plotdata$x)) + 
    theme(plot.title = element_text(hjust = 0.5), axis.text = element_text(size =15))+
    theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),panel.background = element_blank(), axis.line = element_line(colour = "darkgrey"))+
    scale_fill_manual(values=c(col))+scale_y_continuous(expand = c(0,1),breaks = c(round_any(max(h_plotdata$y), 100, f = floor)))
  return(p1)
}
