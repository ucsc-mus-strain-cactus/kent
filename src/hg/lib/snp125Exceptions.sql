# snp125Exceptions.sql was originally generated by the autoSql program, which also 
# generated snp125Exceptions.c and snp125Exceptions.h.  This creates the database representation of
# an object which can be loaded and saved from RAM in a fairly 
# automatic way.

#Annotations for snp125 data
CREATE TABLE snp125Exceptions (
    bin smallint not null,	# Bin number for browser speedup
    chrom varchar(31) not null,	# Chromosome
    chromStart int(10) unsigned not null,	# Start position in chrom
    chromEnd int(10) unsigned not null,	# End position in chrom
    name varchar(15) not null,	# Reference SNP identifier or Affy SNP name
    exception varchar(63) not null,	# Exception found for this SNP
    INDEX name (name),
    INDEX chrom (chrom,bin)
);
