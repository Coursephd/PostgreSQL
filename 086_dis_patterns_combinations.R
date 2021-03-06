####################################################################
#
####################################################################

library(tidyverse)
library(tidytext)
library(stringr)
library(stringi)
library(data.table)
library(stringdist)

# https://stackoverflow.com/questions/43706729/expand-dates-in-data-table

all_met_rmsd <- readRDS ("D:/Hospital_data/ProgresSQL/analysis/all_met_rmsd02.rds")
a2 <- all_met_rmsd [!Code %in% c("", " ", "M2.0") & refcode == "M2.0"]

a2med <- a2 [, description := paste(Type_med, Coded_med),]
a2med <- a2med [ order(description)]
a2med <- a2med [, Code := paste("M", str_pad(.N, width =4, pad="0"), sep =""), by = .(description) ]

a2all <- rbind(a2 [, c("mr_no", "studyday", "refday", "Code", "description", "refcode", "refdesc")], 
                   a2med [, c("mr_no", "studyday", "refday", "Code", "description", "refcode", "refdesc")] )
  
dis <- unique(a2all[, c("mr_no", "studyday", "refday", "Code", "description", "refcode", "refdesc")])
dis <- dis [, `:=` (refday2 = ifelse(refday >=1, "After", "Before"), 
                    Code = str_replace_all (Code, " ", ""),
                    description = str_replace_all(description, " ", "")),]
dis <- dis [ order(mr_no, studyday, Code, refcode, refdesc)]
dis <- dis [, `:=` (alldis = uniqueN(Code), 
                    nrow = seq_len(.N),
                    nrowend = seq_len(.N) + 4,
                    totrow = .N), by = .(mr_no, refcode, refdesc)]
dis <- dis [, `:=` (alldisbfraftr = uniqueN(Code), 
                    nrowbfraftr = seq_len(.N) ), by = .(mr_no, refcode, refdesc, refday2)]

dis02 <- dis [, .(combdis = paste(unique(Code), collapse = ",", sep = " " )), 
              by = .(mr_no, refcode, refdesc, refday2, alldis, totrow)]

unq01comb <- unique( dis02 [, c("mr_no", "refcode", "refdesc", "alldis", "refday2",
                                "totrow",  "combdis"), ])
unq01comb <- unq01comb [, x := 1, ]

# create a copy
unq02comb <- copy(unq01comb)
setnames(unq02comb, "mr_no", "mr_no2")
setnames(unq02comb, "combdis", "combdis2")

unq01comb <- unq01comb [, combdis := str_replace_all(combdis, ",", "|"), ]

# Merge the datasets on x to get all the combinations

unq03comb <- merge(x = unq01comb, 
                   y = unq02comb [, -c("refcode", "refdesc", "totrow", "alldis"), ], 
                   by = c("x", "refday2"), 
                   allow.cartesian = TRUE)

########################################################
# Using str_count function to count the common diseases
# Create tempdis and tempdis2
#
# Consider mr_no as the reference patient
# tempdis: should be lookup
# a: common in both the strings
# b: only present in reference patient (mr_no)
# c: only present in other patient (mr_no2)
# d: complete absence -- not sure how to calculate this
########################################################

unq03comb <- unq03comb [, `:=` (tempdis = str_replace_all(combdis, ",", "|"), 
                                tempdis2 = str_replace_all(combdis2, ",", "|")),]

unq03comb <- unq03comb [, `:=` (cntdis = str_count(tempdis, "\\|") + 1, 
                                cntdis2 = str_count(tempdis2, "\\|") + 1), ]

unq03comb <- unq03comb[, `:=` (a = str_count(combdis2, tempdis)),]

unq03comb <- unq03comb [, `:=` (b = cntdis - a,
                                c = cntdis2 - a),  ]

unq03comb <- unq03comb[, a01jac := (a / (a + b + c)),]
unq03comb <- unq03comb [ mr_no != mr_no2]

distraj <- unique(unq03comb [tempdis != tempdis2 , c("tempdis", "tempdis2", "a01jac", "refday2"),])

distraj01 <- distraj [, .(distraj = .N), by = .(refday2, a01jac)]

cnt <- unq03comb [, .(cnt = uniqueN( paste(mr_no))), by = .(refday2, a01jac)]

chk022 <- melt(data = chk02,
               id.vars = 1:10,
               measure.vars = 11:20,
               variable.name = "distmethod")

fwrite(unq03comb, 
       "D:/Hospital_data/ProgresSQL/analysis/086_dis_patterns_combinations_A2.0.csv")

####################################################################
# End of program
####################################################################



####################################################################
# This is used for 086_dis_count_edges_3rd_byPeriod Tableau display
####################################################################

library(tidyverse)
library(tidytext)
library(stringr)
library(data.table)
library(stringdist)
library(qualV)

# https://stackoverflow.com/questions/43706729/expand-dates-in-data-table

all_met_rmsd <- readRDS ("D:/Hospital_data/ProgresSQL/analysis/all_met_rmsd02.rds")
a2 <- all_met_rmsd [!Code %in% c("", " ") & refcode == "A2.0"]

dis <- unique(a2[!Code %in% c("", " ") & refcode == "A2.0", c("mr_no", "studyday", "refday", "Code", "description", "refcode", "refdesc")])
dis <- dis [, refday2 := ifelse(refday >=1, "After", "Before"), ]
dis <- dis [ order(mr_no, studyday, Code, refcode, refdesc)]
dis <- dis [, `:=` (alldis = uniqueN(Code), 
                    nrow = seq_len(.N),
                    nrowend = seq_len(.N) + 4,
                    totrow = .N), by = .(mr_no, refcode, refdesc)]
dis <- dis [, `:=` (alldisbfraftr = uniqueN(Code), 
                    nrowbfraftr = seq_len(.N) ), by = .(mr_no, refcode, refdesc, refday2)]

dis02 <- dis [, .(combdis = paste(Code, collapse = ",", sep = " " )), 
              by = .(mr_no, refcode, refdesc, refday2, alldis, totrow)]

unq01comb <- unique( dis02 [, c("mr_no", "refcode", "refdesc", "alldis", "refday2",
                                "totrow",  "combdis"), ])
unq01comb <- unq01comb [, x := 1, ]

# create a copy
unq02comb <- copy(unq01comb)
setnames(unq02comb, "mr_no", "mr_no2")
setnames(unq02comb, "combdis", "combdis2")

# Merge the datasets on x to get all the combinations

unq03comb <- merge(x = unq01comb, # [ mr_no == "MR000002"], 
                   y = unq02comb [, -c("refcode", "refdesc", "totrow", "alldis"), ], 
                   by = c("x", "refday2"), 
                   allow.cartesian = TRUE)

chk02 <- unq03comb [, `:=` (dist_jac = stringsim(combdis, combdis2, method = c("jaccard")),
                            dist_osa = stringsim(combdis, combdis2, method = c("osa")),
                            dist_lv  = stringsim(combdis, combdis2, method = c("lv")),
                            dist_dl  = stringsim(combdis, combdis2, method = c("dl")),
                            dist_hamming = stringsim(combdis, combdis2, method = c("hamming")), 
                            dist_lcs  = stringsim(combdis, combdis2, method = c("lcs")),
                            dist_qgram  = stringsim(combdis, combdis2, method = c("qgram")),
                            dist_cosine  = stringsim(combdis, combdis2, method = c("cosine")),
                            dist_jw  = stringsim(combdis, combdis2, method = c("jw")),
                            dist_soundex  = stringsim(combdis, combdis2, method = c("soundex")),
                            dist_lcs  = LCS(combdis, combdis2) ), ]

chk022 <- melt(data = chk02,
               id.vars = 1:10,
               measure.vars = 11:20,
               variable.name = "distmethod")

fwrite(chk022, 
       "D:/Hospital_data/ProgresSQL/analysis/086_dis_patterns_combinations_A2.0.csv")

####################################################################
# End of program
####################################################################
####################################################################
# This is used for 086_dis_count_edges_3rd_byPeriod Tableau display
####################################################################

library(data.table)
library(stringi)
library(stringr)
library(sqldf)
library(tidyr)
library(rjson)
library(jsonlite)
library(dplyr)
library(zoo)
library(tidyr)
library(HDMD)

# https://stackoverflow.com/questions/43706729/expand-dates-in-data-table

all_met_rmsd <- readRDS ("D:/Hospital_data/ProgresSQL/analysis/all_met_rmsd02.rds")

dis <- unique(all_met_rmsd[!Code %in% c("", " ") & refcode == "A2.0", c("mr_no", "studyday", "Code", "description", "refcode", "refdesc")])
dis <- dis [ order(mr_no, studyday, Code, refcode, refdesc)]
dis <- dis [, `:=` (ndis = uniqueN(Code), 
                    nrow = seq_len(.N),
                    nrowend = seq_len(.N) + 4,
                    totrow = .N), by = .(mr_no, refcode, refdesc)]

dis02 <- dis [, .(newgrp = seq(nrow, nrowend, by =1)), by = .(mr_no, Code, description, refcode, refdesc, nrow, nrowend, ndis, totrow)]

dis03 <- dis02 [, .(combdis = paste(Code, collapse = ",", sep = " " )), 
              by = .(mr_no, refcode, refdesc, newgrp, ndis, totrow)]

########################################################
# Get the unique combinations per patient
# Get the numerator -- equal n-grams
# Find the jacard distance for each patient combination
#
# Denominator: distinct n-grams for each 
# patient combination
# num / den for each patient combination, gives jacard
# distance
########################################################

unq01comb <- unique( dis03 [, c("mr_no", "refcode", "refdesc", "combdis"), ])
unq01comb <- unq01comb [, x := 1, ]

# create a copy
unq02comb <- copy(unq01comb)
setnames(unq02comb, "mr_no", "mr_no2")
setnames(unq02comb, "combdis", "combdis2")

# Merge the datasets on x to get all the combinations

unq03comb <- merge(x = unq01comb, # [ mr_no == "MR000002"], 
                   y = unq02comb [, -c("refcode", "refdesc"), ], 
                   by = c("x"), 
                   allow.cartesian = TRUE)

unq04comb <- unq03comb [ combdis == combdis2]
unq04comb <- unq04comb [, num := 1]

num01 <- unq04comb [, .(num01 = sum(num)), by = .(mr_no, mr_no2, refcode, refdesc)]
rm(unq04comb)

###################################
# Get the denominator calculations
###################################

temp01 <- unique( unq03comb [, c("mr_no", "mr_no2", "combdis", "refcode", "refdesc"), ])
temp02 <- unique( unq03comb [, c("mr_no", "mr_no2", "combdis2", "refcode", "refdesc"), ])
setnames(temp02, "combdis2", "combdis")

temp03 <- unique( rbind (temp01, temp02))

rm(temp01); rm(temp02)
rm(unq03comb)

den01 <- temp03 [, .(den01 = .N), by = .(mr_no, mr_no2, refcode, refdesc)]

rm(temp03)

jacard01 <- merge(x = num01,
                  y = den01,
                  by = c("mr_no", "mr_no2", "refdesc", "refcode"),
                  all.x = TRUE)
jacard01 <- jacard01 [, dist := (num01 / den01) * 100, ]

jacard01trn <- dcast(data = jacard01, 
                     refcode + refdesc + mr_no ~ mr_no2, 
                     value.var = c ("dist"), 
                     fill = 0)

#dis03cnt <- dis03 [, .(npat = uniqueN(mr_no)), by = .(combdis)]

unqdis <- unique( dis [, c("mr_no", "ndis", "totrow", "refcode", "refdesc"), ])
alldis <- dis02 [, .(alldis = paste(unique(Code), collapse = ",", sep = " " ),
                     alldesc = paste(unique(description), collapse = ",", sep = " " )), 
                by = .(mr_no, refcode, refdesc)]

# Combine all variables into 1 dataset ADSL
alldis <- Reduce(function(...) merge(..., all = TRUE, by = c("mr_no", "refcode", "refdesc")),
               list(unqdis, alldis, jacard01trn) )

fwrite(alldis, 
       "D:/Hospital_data/ProgresSQL/analysis/086_dis_patterns_combinations_A2.0.csv")
