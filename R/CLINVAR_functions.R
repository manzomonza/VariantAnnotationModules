################################################# Check for presence of Clinvar variant summary file (and it being up-to-date)   #################################################

################################################# )   #################################################
#' Check, download and update Clinvar Summary Table (from NIH)
#' Checks for presence of Clinvar variant summary file (and it being up-to-date).
#' If not present (or up-to date, downloads from NIH at absolute path)
#' Caveat: Absolute paths are specified
#' @param CLINVAR_SUMMARY_FILEPATH Absolute filepath of clinvar summary file
#' @return Boolean indicating if downloaded file has same MD5checksum as MD5checksum on NIH website
#'
#' @export
#'
#' @examples
clinvarCheck <- function(){
  ## check if new variant summary tables were created
  # clinvarDir <- getURL("https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/",
  #                      verbose=TRUE,ftp.use.epsv=TRUE, dirlistonly = TRUE)
  #
  # return(getHTMLLinks(clinvarDir))
  ## new solution
  ## Check if MD5 sum of local variant_summary.txt.gz matches the current online one
  if(!file.exists(CLINVAR_SUMMARY_FILEPATH)){
    download.file("https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/variant_summary.txt.gz",
                  destfile=CLINVAR_SUMMARY_FILEPATH)
  }
  md5check <- md5sum(CLINVAR_SUMMARY_FILEPATH) ==
    strsplit(getURL("https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/variant_summary.txt.gz.md5"), split = " ")[[1]][1]

  return(md5check)
}


#' Calls function to process variant table and check variants for entries in Clinvar table
#'
#' @param snv_table
#' @param clinvar
#'
#' @return
#' @export
#'
#' @examples
ClinVar_function_call = function(snv_table, clinvar){
  asnv = amino_acid_code_1_to_3(snv_table)
  asnv$protein = unname(sapply(asnv$protein, fsClinvarfix))
  asnv$ClinVar_Significance = NA
  asnv$ClinVar_VariationID = NA
  for(i in 1:nrow(asnv)){
    clinhit = clinvar_filtering(genestr = asnv$gene[i], codingstr = asnv$coding[i], proteinstr = asnv$protein[i], clinvar = clinvar )
    if(typeof(clinhit) == 'list'){
      clinhit = somatic_filtering(clinhit)
      asnv$ClinVar_Significance[i] = paste0(clinhit$clinical_significance, collapse = ";")
      asnv$ClinVar_VariationID[i] = paste0(clinhit$variation_id, collapse = ";")
      # if(nrow(clinhit) !=1){
      #   asnv$ClinVar_Significance[i] = list(clinhit$clinical_significance)
      #   asnv$ClinVar_VariationID[i] = list(clinhit$variation_id)
      # }else{
      #   asnv$ClinVar_Significance[i] = clinhit$clinical_significance
      #   asnv$ClinVar_VariationID[i] = clinhit$variation_id
      # }
    }else{
      next
    }
  }
  return(asnv)
}

#' Frameshift clinvar fix
#'
#' @param amino_acid_change
#'
#' @return
#' @export
#'
#' @examples
#' removes 'stop after how many amino-acids' information, e.g.
#' # p.Ser1465ArgfsTer3 to p.Ser1465fs
fsClinvarfix <- function(amino_acid_change){
  # Is fs present
  if( !is.null(amino_acid_change)){
    if(!is.na(amino_acid_change) & !grepl("p\\.\\?", amino_acid_change) ){
      if(grepl("fs", amino_acid_change,fixed = TRUE)){
        split_string = stringr::str_split(amino_acid_change, pattern = "\\d{1,}", simplify = TRUE)[,1]
        digit_split = stringr::str_extract(amino_acid_change, pattern = "\\d{1,}")
        fs_string = paste0(split_string, digit_split, "fs")
        return(fs_string)
      }else{
        return(amino_acid_change)
      }
    }else{
      return(NA)
    }
  }else{
    return(NA)
  }
}


#' Filter CLINVAR table based on gene, protein coding first.
#' If coding and protein are  given, but coding does not match, then search for proteinstr only
#'
#' @param genestr
#' @param codingstr
#' @param proteinstr
#' @param clinvar
#'
#' @return
#' @export
#'
#' @examples
clinvar_filtering = function(genestr, codingstr, proteinstr, clinvar){
  proteinstr = ifelse(proteinstr == "p.?", NA, proteinstr)
  if(is.na(codingstr) & is.na(proteinstr)){
    return(NA)
    }

  if(!is.na(codingstr) & is.na(proteinstr)){
    clinvar_hit = clinvar_check_gene(genestr = genestr, clinvar_fil = clinvar)
    clinvar_hit = clinvar_check_coding(codingstr = codingstr, clinvar_fil = clinvar_hit)
    return(clinvar_hit)
    }

  if(is.na(codingstr) & !is.na(proteinstr)){
    clinvar_hit = clinvar_check_gene(genestr = genestr, clinvar_fil = clinvar)
    clinvar_hit = clinvar_check_protein(proteinstr = proteinstr, clinvar_fil = clinvar_hit)
    return(clinvar_hit)
  }

  if(!is.na(codingstr) & !is.na(proteinstr)){
    clinvar_hit = clinvar_check_gene(genestr = genestr, clinvar_fil = clinvar)
    clinvar_hit = clinvar_check_coding(codingstr = codingstr, clinvar_fil = clinvar_hit)
    clinvar_hit = clinvar_check_protein(proteinstr = proteinstr, clinvar_fil = clinvar_hit)
    if(nrow(clinvar_hit) == 0){
      clinvar_hit = clinvar_check_gene(genestr = genestr, clinvar_fil = clinvar)
      clinvar_hit = clinvar_check_protein(proteinstr = proteinstr, clinvar_fil = clinvar_hit)
    }
    return(clinvar_hit)
  }
}




#' Filter for 'somatic' classification  in case of multiple ClinVar entries
#'
#' @param clinvarhits
#'
#' @return
#' @export
#'
#' @examples
somatic_filtering = function(clinvarhits){
  if(nrow(clinvarhits) == 1){
    return(clinvarhits)
    }
  clinvarhits = dplyr::filter(clinvarhits, grepl("somatic", origin_simple))
  return(clinvarhits)
}



#' Return Clinical significance entry from Clinvar table
#'
#' @param clinvar_hit
#'
#' @return
#' @export
#'
#' @examples
clinvar_significance = function(clinvar_hit){
  if(typeof(clinvar_hit) !='character'){
    significance = clinvar_hit$clinical_significance
  }else{
    significance = NA
  }
  return(significance)
}

#' Return Variation ID entry from Clinvar table
#'
#' @param clinvar_hit
#'
#' @return
#' @export
#'
#' @examples
clinvar_variantID = function(clinvar_hit){
  if(typeof(clinvar_hit) !='character'){
    varid = clinvar_hit$variation_id
  }else{
    varid = NA
  }
  return(varid)
}

#' Check gene string for presence in clinvar_fil
#'
#' @param genestr
#' @param clinvar_fil
#'
#' @return
#' @export
#'
#' @examples
clinvar_check_gene = function(genestr, clinvar_fil){
  clinvar_fil = dplyr::filter(clinvar_fil, gene_symbol == genestr )
  clinvar_fil = dplyr::collect(clinvar_fil)
  clinvar_fil = dplyr::distinct(clinvar_fil)
  clinvar_fil = dplyr::filter(clinvar_fil, grepl(genestr, name, fixed = TRUE ))
  return(clinvar_fil)
}

#' Check coding string for presence in clinvar_fil
#'
#' @param genestr
#' @param clinvar_fil
#'
#' @return
#' @export
#'
#' @examples
clinvar_check_coding = function(codingstr, clinvar_fil){
  clinvar_fil = dplyr::filter(clinvar_fil, grepl(codingstr, name, fixed = TRUE ))
  return(clinvar_fil)
}
#' Check protein string for presence in clinvar_fil
#'
#' @param genestr
#' @param clinvar_fil
#'
#' @return
#' @export
#'
#' @examples
clinvar_check_protein = function(proteinstr, clinvar_fil){
  clinvar_fil = dplyr::filter(clinvar_fil, grepl(proteinstr, name, fixed = TRUE ))
  return(clinvar_fil)
}
