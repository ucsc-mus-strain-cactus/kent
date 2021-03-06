# gtexSampleData.sql was originally generated by the autoSql program, which also 
# generated gtexSampleData.c and gtexSampleData.h.  This creates the database representation of
# an object which can be loaded and saved from RAM in a fairly 
# automatic way.

#GTEX Expression data (RPKM levels, unmapped)
CREATE TABLE gtexSampleData (
    geneId varchar(255) not null,	# Gene identifier (ensembl)
    sample varchar(255) not null,	# GTEX sample identifier
    tissue varchar(255) not null,	# Tissue short name
    score float not null,	# Expression level (RPKM)
              #Indices
    KEY(geneId),
    KEY(tissue)
);
