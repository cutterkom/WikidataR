# -------- Writes --------

#'@title Write statements to Wikidata
#'@description Upload data to wikidata, including creating items,
#'adding statements to existing items (via the quickstatements format and API).
#'
#'@param items a vector of strings indicating the items to which to add statements (as QIDs or labels).
#'Note: if labels are provided, and multiple items match, the first matching item will be used
#'(see \code{as_qid} function), so use with caution.
#'New QIDs can be created by using the "CREATE_xyz", where "_xyz" is any unique string.
#'Using the same id will add additional statements to those new items 
#'@param properties a vector of strings indicating the properties to add as statements (as PIDs or labels).
#'Note: if labels are provided, and multiple items match, the first matching item will be used
#'(see \code{as_pid} function), so use with caution.
#'Four special properties can also be used: labels, aliases, descriptions and sitelinks.
#'See [this link](https://www.wikidata.org/wiki/Help:QuickStatements#Adding_labels,_aliases,_descriptions_and_sitelinks) for the syntax.
#'@param values a vector of strings indicating the values to add as statements (as QIDs or strings).
#'Note: if strings are provided, they will be treated as plain text.
#'@param qual.properties a vector, data frame, or tibble of strings indicating the properties to add as qualifiers to statements (as PIDs or labels).
#'Note: if labels are provided, and multiple items match, the first matching item will be used
#'(see \code{as_pid} function), so use with caution.
#'@param qual.values a vector, data frame, or tibble of strings indicating the values to add as statements (as QIDs or strings).
#'Note: if strings are provided, they will be treated as plain text.
#'@param src.properties a vector, data frame, or tibble of strings indicating the properties to add as reference sources to statements (as SIDs or labels).
#'Note: if labels are provided, and multiple items match, the first matching item will be used
#'(see \code{as_sid} function), so use with caution.
#'@param src.values a vector, data frame, or tibble of strings indicating the values to add reference sources to statements (as QIDs or strings).
#'Note: if strings are provided, they will be treated as plain text.
#'@param remove a vector of boolians for each statemnt indicating whether it should
#'be removed from the item rather than added (default = FALSE)
#'@param format output format as a string. Options include:
#' \describe{
#'   \item{tibble}{easiest format to further manuipulation in R}
#'   \item{csv}{can be copy-pasted to [the QuickStatements website](https://quickstatements.toolforge.org/) (or manipulated in a spreadsheet programs)}
#'   \item{api}{a url that can be copy-pasted into a web browser, or automatically submitted (see \code{api.submit} parameter)}
#'   \item{website}{open a [QuickStatements](https://quickstatements.toolforge.org/) web browser window summarising the edits to be made to Wikidata)}
#' }
#'@param api.username a string indicating your wikimedia username 
#'@param api.token a string indicating your api token (the unique identifier that you can find listed at [your user page](https://quickstatements.toolforge.org/#/user))
#'@param api.format a string indicateing which version of the quickstatement format used to submit the api (default = "v1")
#'@param api.batchname a string create a named batch (listed at [your batch history page](https://quickstatements.toolforge.org/#/batches)) and tag in the edit summaries
#'@param api.submit boolian indicating whether to submit instruction directly to wikidata (else returns the URL that can be copy-pasted into a web browser)
#'
#'@return data formatted to upload to wikidata (via quickstatemsnts),
#'optionally also directly uploded to wikidata (see \code{format} parameter). 
#'
#'@examples
#'# Add a statement to the "Wikidata sandbox" item (Q4115189)
#'# to say that it is an "instance of" (P31) of Q1 (the universe).
#'# The instruction will submit directly to wikidata via the API
#'# (if you include your wikimedia username and token)
#'
#' \dontrun{write_wikidata(items        = "Wikidata Sandbox",
#'                properties   = "instance of",
#'                values       = "Q1",
#'                format       = "api",
#'                api.username = "myusername", 
#'                api.token    = , #REDACTED#
#'                )}
#'#note: 
#'
#'@export

write_wikidata <- function(items,
                           properties      = NULL,
                           values          = NULL,
                           qual.properties = NULL,
                           qual.values     = NULL,
                           src.properties  = NULL,
                           src.values      = NULL,
                           remove          = FALSE,
                           format          = "tibble",
                           api.username    = NULL,
                           api.token       = NULL, # Find yours from [your user page](https://tools.wmflabs.org/quickstatements/#/user)
                           api.format      = "v1",
                           api.batchname   = NULL,
                           api.submit      = TRUE
){
  
  # Check if username and token provided
  if(format=="api"){
    if(is.null(api.username)){stop("Enter your Wikimedia username")}
    if(is.null(api.token))   {stop("Enter your api.token (Find yours at https://tools.wmflabs.org/quickstatements/#/user)")}
  }
  
  # Place all the quickstatements variables into a list 
  QS <- list(items           = items,
             properties      = properties,
             values          = values,
             qual.properties = qual.properties,
             qual.values     = qual.values,
             src.properties  = src.properties,
             src.values      = src.values)
  QS <- lapply(QS,function(x){if(!is.null(x)){tibble(x)}})

  # If new QIDs are being created via the "CREATE" keyword, need to insert blank lines across the other parameters to align correctly into rows
  # This is the most similar to the standard quickstatements method, though the "CREATExyz" method is preferred (see createrows.tidy function later)
  QS$properties      <- createrows(QS$items,QS$properties)
  QS$values          <- createrows(QS$items,QS$values)
  QS$qual.properties <- createrows(QS$items,QS$qual.properties)
  QS$qual.values     <- createrows(QS$items,QS$qual.values)
  QS$src.properties  <- createrows(QS$items,QS$src.properties)
  QS$src.values      <- createrows(QS$items,QS$src.values)
  
  # If same number of rows as the rowmax, do nothing
  # If only one row, repeat it rowmax times
  # If wrong number of rows, stop with an error message
  rowcount <- unlist(lapply(QS,nrow))
  rowmax   <- max(rowcount)
  stoprun  <- FALSE
  
  if(var(unlist(rowcount))!=0){
    for (x in 1:length(QS)){
      if(is.null(nrow(QS[[x]]))){
        QS[[x]] <- slice(tibble(QS[[x]]),rep(1:n(), each=rowmax))
      }else if (nrow(QS[[x]])==1){ 
        QS[[x]] <- slice(tibble(QS[[x]]),rep(1:n(), each=rowmax)) 
      }else if(nrow(QS[[x]])==rowmax){ 
        QS[[x]] <- QS[[x]]
      }else{
        stoprun<-TRUE
        warning(paste0("Not all quickstatement columns have equal rows: ",
                       nrow(QS$items)," items (including ",
                       sum(is.create(unlist(QS$items)))," new QIDs to CREATE) were provided, but ",
                       names(QS)[x],
                       " has ",
                       nrow(QS[[x]]),
                       " rows (expecting ",
                       nrow(QS$items),
                       ")."))
      }
    }
  }
  if(stoprun){stop("Therefore stopping")}
  
  # Convert values to QIDs where possible and identify which (if any) to remove
  QS$items           <- as_qid(QS$items)
  QS$items[remove,]  <- paste0("-",unlist(QS$items[remove,]))
  
  # Convert properties to PIDs where possible, unless special functions (such as lables and aliases)
  QS$properties      <- as_pid(QS$properties)
  
  # Convert values to QIDs where possible, unless property is expecting a string
  QS$values          <- tibble(QS$values)
  if(any(sapply(QS$properties,check.PID.WikibaseItem))){
    QS$values[sapply(QS$properties,check.PID.WikibaseItem),] <- as_qid(QS$values[sapply(QS$properties,check.PID.WikibaseItem),])
  }
  QS$values          <- as_quot(QS$values,format)
  
  # Check if multiple values and properties supplied for each item
  if(!is.null(dim(QS$properties))){
    if(all (dim(QS$properties) != dim(QS$values))){
      stop("multiple properties and values supplied for each item, but number of properties and values don't match")
    }
    QS$items      <- tibble(rep(unlist(QS$items),each=ncol(QS$properties)))
    QS$properties <- tibble(as.vector(t(QS$properties)))
    QS$values     <- tibble(as.vector(t(QS$values)))
  }
  
  # Convert first three columns into tibble (tibbulate?)
  colnames(QS$items)      <- "Item"
  colnames(QS$properties) <- "Prop"
  colnames(QS$values)     <- "Value"
  
  QS.tib <- bind_cols(QS$items,
                      QS$properties,
                      QS$values)  

  # optionally, append columns for qualifier properties and qualifier values for those statements
  if(!is.null(QS$qual.properties)|!is.null(QS$qual.values)){
    QS$qual.properties <- as_pid(QS$qual.properties)
    QS$qual.values     <- as_quot(QS$qual.values,format)
    
    # if no value, clear property 
    QS$qual.properties[QS$qual.values==""|is.na(QS$qual.values)] <- NA

    colnames(QS$qual.properties) <- paste0("qual.prop.",1:ncol(QS$qual.properties))
    colnames(QS$qual.values)     <- paste0("qual.value.",1:ncol(QS$qual.values))
    
    QSq <- list(QS$qual.properties,
                QS$qual.values)
    
    QSq.check  <- var(sapply(c(QS,QSq),function(x){if(is.null(dim(x))){length(x)}else{nrow(x)}}))==0
    if(!QSq.check){stop("Incorrect number of qualifiers provided. If no qualifers needed for a statement, use NA or \"\".")}
    
    QS.qual.tib <- as_tibble(cbind(QSq[[1]],QSq[[2]])[,c(rbind(1:ncol(QSq[[1]]),ncol(QSq[[1]])+1:ncol(QSq[[2]])))])
    
    QS.tib <- tibble(QS.tib,
                     QS.qual.tib)
  }
  
  # optionally, append columns for source properties and source values for those statements
  if(!is.null(src.properties)|!is.null(src.values)){
    QS$src.properties <- as_sid(QS$src.properties)
    QS$src.values     <- as_quot(QS$src.values,format)

    # if no value, clear property 
    QS$src.properties[QS$src.values==""|is.na(QS$src.values)] <- NA

    colnames(QS$src.properties) <- paste0("src.prop.",1:ncol(QS$src.properties))
    colnames(QS$src.values)     <- paste0("src.values.",1:ncol(QS$src.values))
    
    QSs <- list(QS$src.properties,
                QS$src.values)
    QSs.check  <- var(sapply(c(QS,QSs),function(x){if(is.null(dim(x))){length(x)}else{nrow(x)}}))==0
    if(!QSs.check){stop("incorrect number of sources provided")}
    
    QS.src.tib <- as_tibble(cbind(QSs[[1]],QSs[[2]])[,c(rbind(1:ncol(QSs[[1]]),ncol(QSs[[1]])+1:ncol(QSs[[2]])))])
    
    QS.tib <- tibble(QS.tib,
                     QS.src.tib)
  }
  
  # if new QIDs are being created via tidy "CREATExyz" keywords, need to insert CREATE lines above and replace subsequent "CREATExyz" with "LAST"
  QS.tib <- createrows.tidy(QS.tib)
  
  # remove any impossible rows (value is NA)
  if(nrow(QS.tib)!=1){
    QS.tib <- QS.tib[!is.na(QS.tib$Value),]
    QS.tib <- as_tibble(apply(QS.tib,2,replace_na,"")) 
  }
  
  # format up the output
  if (format=="csv"){
    write.table(QS.tib,quote = FALSE,row.names = FALSE,sep = ",")
  }
  
  if (format=="tibble"){
    return(QS.tib)
  }
  
  if (format=="website"){
    api.temp1 <- format_tsv(QS.tib, col_names = FALSE, quote_escape = "none")
    api.temp2 <- gsub("\t", "%7C",api.temp1)       # Replace TAB with "%7C"
    api.temp3 <- gsub("%7C(%7C)+","%7C",api.temp2) # Replace multiple tabs (from missing values) with a single tab (to distinguish from newlines)
    api.temp4 <- gsub("\n", "%7C%7C",api.temp3)    # Replace end-of-line with "%7C%7C"
    api.temp5 <- gsub(" ",  "%20",api.temp4)       # Replace space with "%20"
    api.temp6 <- gsub("\\+","%2B",api.temp5)       # Replace plus with "%2B"
    api.data  <- gsub("/",  "%2F",api.temp6)       # Replace slash with "%2F"
    
    url <- paste0("https://quickstatements.toolforge.org/#/v1=","&data=%7C%7C",api.data)
    
    if(api.submit){ 
      browseURL(url)
    }else{
      return(url)
    }
  }
  
  if (format=="api"){
    api.temp1 <- format_tsv(QS.tib, col_names = FALSE, quote_escape = "none")
    api.temp2 <- gsub("%22","\"",api.temp1) #cludge to fix as_quote issues
    api.data  <- gsub("%2F","/",api.temp2) #cludge to fix as_date issues
    
    if (api.submit){
      POST(url="https://tools.wmflabs.org/quickstatements/api.php",
               body = list(action    = "import",
                           submit    = "1",
                           format    = api.format,
                           batchname = api.batchname,
                           username  = api.username,
                           token     = api.token,
                           data      = api.data)
           )
      browseURL("https://quickstatements.toolforge.org/#/batches")
    }else{
      api.temp1 <- format_tsv(QS.tib, col_names = FALSE, quote_escape = "none")
      api.temp2 <- gsub("\t", "%7C",api.temp1)       # Replace TAB with "%7C"
      api.temp3 <- gsub("%7C(%7C)+","%7C",api.temp2) # Replace multiple tabs (from missing values) with a single tab (to distinguish from newlines)
      api.temp4 <- gsub("\n", "%7C%7C",api.temp3)    # Replace end-of-line with "%7C%7C"
      api.temp5 <- gsub(" ",  "%20",api.temp4)       # Replace space with "%20"
      api.temp6 <- gsub("\\+","%2B",api.temp5)       # Replace plus with "%2B"
      api.data  <- gsub("/",  "%2F",api.temp6)       # Replace slash with "%2F"
      url <- paste0("https://tools.wmflabs.org/quickstatements/api.php",
                    "?action=",    "import",
                    "&submit=",    "1",
                    "&format=",    api.format,
                    "&batchname=", api.batchname,
                    "&username=",  api.username,
                    "&token=",     api.token,
                    "&data=%7C%7C",api.data)
      return(url)
    }
  }
}
