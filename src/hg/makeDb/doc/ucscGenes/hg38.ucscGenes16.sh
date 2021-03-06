
export dir=/cluster/data/hg38/bed/ucsc.16.5
export GENCODE_VERSION=V22
export oldGeneDir=/cluster/data/hg38/bed/ucsc.15.1
export oldGeneBed=$oldGeneDir/ucscGenes.bed
export db=hg38
export spDb=sp150225
export taxon=9606
export tempDb=tmpFoo67
export kent=$HOME/kent
export lastVer=8
export curVer=9
export Db=Hg38
export xdb=mm10
export Xdb=Mm10
export ydb=canFam3
export zdb=rheMac3
export ratDb=rn4
export RatDb=Rn4
export fishDb=danRer7
export flyDb=dm3
export wormDb=ce6
export yeastDb=sacCer3
export tempFa=$dir/ucscGenes.faa
export genomes=/hive/data/genomes
export xdbFa=$genomes/$xdb/bed/ucsc.13.1/ucscGenes.faa
export ratFa=$genomes/$ratDb/bed/blastpRgdGene2/rgdGene2Pep.faa
export fishFa=$genomes/$fishDb/bed/blastp/ensembl.faa
export flyFa=$genomes/$flyDb/bed/hgNearBlastp/100806/$flyDb.flyBasePep.faa
export wormFa=$genomes/$wormDb/bed/blastp/wormPep190.faa
export yeastFa=$genomes/$yeastDb/bed/sgdAnnotations/blastTab/sacCer3.sgd.faa
export scratchDir=/hive/users/braney/scratch

export blastTab=hgBlastTab
export xBlastTab=mmBlastTab
export rnBlastTab=rnBlastTab
export dbHost=hgwdev
export ramFarm=ku
export cpuFarm=ku

mkdir -p $dir
cd $dir

echo "create database $tempDb" | hgsql ""

echo "create table knownGeneOld$lastVer like  $db.knownGene" | hgsql $tempDb
echo "insert into knownGeneOld$lastVer select * from   $db.knownGene" | hgsql $tempDb
echo "create table kgXrefOld$lastVer like  $db.kgXref" | hgsql $tempDb
echo "insert into kgXrefOld$lastVer select * from   $db.kgXref" | hgsql $tempDb

hgsql -e "select * from wgEncodeGencodeComp$GENCODE_VERSION" --skip-column-names hg38 | cut -f 2-16 |  genePredToBed stdin stdout |  tawk '{$4=$4 "." $1; print}' |  gzip -c > gencode${GENCODE_VERSION}Comp.bed.gz


#TODO:  figure out better wayto deal with txLastId
cp ~kent/src/hg/txGene/txGeneAccession/txLastId startId

txGeneAccession -test $oldGeneBed ~kent/src/hg/txGene/txGeneAccession/txLastId gencode${GENCODE_VERSION}Comp.bed.gz txToAcc.tab oldToNew.tab

tawk '{print $4}' oldToNew.tab | sort | uniq -c
# 43681 compatible
# 9459 exact
# 51038 lost
# 142038 new

# check to make sure we don't have any dups.  These two numbers should
# be the same.   
awk '{print $2}' txToAcc.tab | sed 's/\..*//' | sort -u | wc -l
# 195178
awk '{print $2}' txToAcc.tab | sed 's/\..*//' | sort  | wc -l
# 195178

# this should be the current db instead of olDdb if not the first release
echo "select * from knownGene" | hgsql $db | sort > $db.knownGene.gp
echo "create table knownGeneOld${lastVer} select * from hg38.knownGene" | hgsql $tempDb
grep lost oldToNew.tab | awk '{print $2}' | sort > lost.txt
join lost.txt $db.knownGene.gp > $db.lost.gp

awk '{if ($7 == $6) print}' $db.lost.gp | wc -l
# non-coding 27206
awk '{if ($7 != $6) print}' $db.lost.gp | wc -l
# coding 23832

# Assign permanent accessions to each transcript, and make up a number
# of our files with this accession in place of the temporary IDs we've been
# using.  Takes 4 seconds

cd $dir
cp ~kent/src/hg/txGene/txGeneAccession/txLastId saveLastId
txGeneAccession $oldGeneBed saveLastId gencode${GENCODE_VERSION}Comp.bed.gz txToAcc.tab oldToNew.tab
subColumn 4 gencode${GENCODE_VERSION}Comp.bed.gz txToAcc.tab ucscGenes.bed
twoBitToFa /cluster/data/$db/$db.2bit -bed=ucscGenes.bed ucscGenes.fa
bedToPsl /cluster/data/hg38/chrom.sizes ucscGenes.bed ucscGenes.psl
pslRecalcMatch ucscGenes.psl /cluster/data/$db/$db.2bit ucscGenes.fa kgTargetAli.psl
# should be zero
awk '$11 != $1 + $3+$4' kgTargetAli.psl

hgLoadPsl $tempDb kgTargetAli.psl

getRnaPred -peptides $tempDb knownGene all ucscGenes.faa
hgPepPred $tempDb generic knownGenePep ucscGenes.faa

txBedToGraph ucscGenes.bed ucscGenes ucscGenes.txg
txgAnalyze ucscGenes.txg $genomes/$db/$db.2bit stdout | sort | uniq > ucscSplice.bed
hgLoadBed $tempDb knownAlt ucscSplice.bed

#hgsql -N $spDb -e "select p.acc, p.val from protein p, accToTaxon x where x.taxon=$taxon and p.acc=x.acc" | awk '{print ">" $1;print $2}' >uniProt.fa
#faSize uniProt.fa

#needs two passes.  First make knownGene, then supporting tables
makeGencodeKnownGene -justKnown $db $tempDb $GENCODE_VERSION txToAcc.tab

hgLoadSqlTab -notOnServer $tempDb knownGene $kent/src/hg/lib/knownGene.sql knownGene.gp

hgMapToGene -all -tempDb=$tempDb $db all_mrna knownGene knownToMrna
hgMapToGene -tempDb=$tempDb $db refGene knownGene knownToRefSeq
hgMapToGene -tempDb=$tempDb $db all_mrna knownGene knownToMrnaSingle

makeGencodeKnownGene $db $tempDb $GENCODE_VERSION txToAcc.tab
 
hgLoadSqlTab -notOnServer $tempDb knownIsoforms $kent/src/hg/lib/knownIsoforms.sql knownIsoforms.tab

hgLoadSqlTab -notOnServer $tempDb kgXref $kent/src/hg/lib/kgXref.sql kgXref.tab

hgLoadSqlTab -notOnServer $tempDb knownCanonical $kent/src/hg/lib/knownCanonical.sql knownCanonical.tab


hgsql $tempDb -e "select * from knownToMrna" | tail -n +2 | tawk '{if ($1 != last) {print last, count, buffer; count=1; buffer=$2} else {count++;buffer=$2","buffer} last=$1}' | tail -n +2 | sort > tmp1
hgsql $tempDb  -e "select * from knownToMrnaSingle" | tail -n +2 | sort > tmp2
join  tmp2 tmp1 > knownGene.ev

txGeneAlias $db $spDb kgXref.tab knownGene.ev oldToNew.tab foo.alias foo.protAlias
sort foo.alias | uniq > ucscGenes.alias
sort foo.protAlias | uniq > ucscGenes.protAlias
rm foo.alias foo.protAlias
hgLoadSqlTab -notOnServer $tempDb kgAlias $kent/src/hg/lib/kgAlias.sql ucscGenes.alias
hgLoadSqlTab -notOnServer $tempDb kgProtAlias $kent/src/hg/lib/kgProtAlias.sql ucscGenes.protAlias

# Build kgSpAlias table, which combines content of both kgAlias and kgProtAlias tables.

hgsql $tempDb -N -e 'select kgXref.kgID, spID, alias from kgXref, kgAlias where kgXref.kgID=kgAlias.kgID' > kgSpAlias_0.tmp
         
hgsql $tempDb -N -e 'select kgXref.kgID, spID, alias from kgXref, kgProtAlias where kgXref.kgID=kgProtAlias.kgID' >> kgSpAlias_0.tmp
cat kgSpAlias_0.tmp|sort -u  > kgSpAlias.tab
rm kgSpAlias_0.tmp

hgLoadSqlTab -notOnServer $tempDb kgSpAlias $kent/src/hg/lib/kgSpAlias.sql kgSpAlias.tab

txGeneExplainUpdate2 $oldGeneBed ucscGenes.bed kgOldToNew.tab
hgLoadSqlTab -notOnServer $tempDb kg${lastVer}ToKg${curVer} $kent/src/hg/lib/kg1ToKg2.sql kgOldToNew.tab
# add kg${lastVer}ToKg${curVer} to all.joiner !!!!

# fake kgColor
tawk '{print $1, 0, 0, 0}' knownGene.gp > knownGene.color
hgLoadSqlTab -notOnServer $tempDb kgColor $kent/src/hg/lib/kgColor.sql knownGene.color


sort txToAcc.tab > tmp1
hgsql -e "select * from wgEncodeGencodeComp$GENCODE_VERSION" --skip-column-names hg38 | cut -f 2-16 |  tawk '{print $1 "." $2,$13,$14,$8,$15}' | sort | join /dev/stdin tmp1 | awk 'BEGIN {OFS="\t"} {print $6, $2, $3, $4, $5}' | sort > knownCds.tab
hgLoadSqlTab -notOnServer $tempDb knownCds $kent/src/hg/lib/knownCds.sql knownCds.tab

sed 's/\.chr.*\t/\t/' txToAcc.tab | sort  > tmp1
hgsql -e "select * from wgEncodeGencodeTag$GENCODE_VERSION" --skip-column-names hg38 | subColumn 1 stdin tmp1 stdout -miss=missedTags.txt | grep -v "^ENS" | sort > knownToTag.tab
hgLoadSqlTab -notOnServer $tempDb knownToTag $kent/src/hg/lib/knownTo.sql knownToTag.tab

#zcat /cluster/data/hg38/bed/gencodeV22/data/release_22/gencode.v22.pc_translations.fa.gz | sed 's/.*ENST/>ENST/' | sed 's/|.*//' | tawk '/>/ {name=$1} ! />/ {print name, $0}' | tr -d '>' |sort > tmp11
#join tmp11 tmp1 | awk '{printf ">%s\n%s\n",$3,$2}' > ucscGenes.faa
# this is missing the PAR genes 
#hgPepPred $tempDb generic knownGenePep ucscGenes.faa

 #zcat /cluster/data/hg38/bed/gencodeV22/data/release_22/gencode.v22.pc_transcripts.fa.gz | sed 's/.*ENST/>ENST/' | sed 's/|.*//' | awk '/>/ {name=$1} ! />/ {print name, $0}' | tr -d '>' |sort > tmp12
#join tmp12 tmp1 | awk '{printf ">%s\n%s\n",$3,$2}' > ucscGenes.fa
#hgPepPred $tempDb generic knownGeneMrna ucscGenes.fa

hgKgGetText $tempDb knownGene.text 
ixIxx knownGene.text knownGene.ix knownGene.ixx

rm -rf /gbdb/$tempDb/knownGene.ix /gbdb/$tempDb/knownGene.ixx
ln -s $dir/knownGene.ix  /gbdb/$tempDb/knownGene.ix
ln -s $dir/knownGene.ixx /gbdb/$tempDb/knownGene.ixx  

hgsql --skip-column-names -e "select mrnaAcc,locusLinkId from refLink" $db > refToLl.txt
hgMapToGene -tempDb=$tempDb $db refGene knownGene knownToLocusLink -lookup=refToLl.txt
knownToVisiGene $tempDb -probesDb=$db

#touch empty.ev
#/cluster/home/braney/bin/x86_64/txGeneAlias hg19 uniProt kgXref.tab empty.ev oldToNew.tab alias.tab proAlias.tab
#sort alias.tab | uniq > kgAlias.tab
#sort proAlias.tab | uniq > kgProtAlias.tab

tawk '{print $2,$1}' tmp1 | sort > knownToEnsemble.tab
tawk '{print $2,$1}' tmp1 | sort > knownToGencode${GENCODE_VERSION}.tab
hgLoadSqlTab -notOnServer $tempDb  knownToEnsembl  $kent/src/hg/lib/knownTo.sql  knownToEnsembl.tab
hgLoadSqlTab -notOnServer $tempDb  knownToGencode${GENCODE_VERSION}  $kent/src/hg/lib/knownTo.sql  knownToGencode${GENCODE_VERSION}.tab

hgMapToGene -tempDb=$tempDb $db gnfAtlas2 knownGene knownToGnfAtlas2 '-type=bed 12'

# start not done

# Make up and load kgColor table. Takes about a minute.
$txGeneColor $spDb ucscGenes.info ucscGenes.picks ucscGenes.color
$hgLoadSqlTab -notOnServer $tempDb kgColor $kent/src/hg/lib/kgColor.sql ucscGenes.color

# Load up kgProtMap2 table that says where exons are in terms of CDS
$txGeneCdsMap weeded.bed weeded.info pick.picks refTweaked.psl \
	refToPep.tab $genomes/$db/chrom.sizes cdsToRna.psl \
	rnaToGenome.psl
# Missed 337 of 40856 refSeq protein mappings.  A small number of RefSeqs just map to genome in the UTR.

$pslMap cdsToRna.psl rnaToGenome.psl cdsToGenome.psl
$hgLoadPsl $tempDb ucscProtMap.psl -table=kgProtMap2



# TODO: Create knownToTreefam table.
$mkdir -p $dir/treeFam
$cd $dir/treeFam
$wget "http://www.treefam.org/static/download/treefam_family_data.tar.gz"
$tar xfz treefam_family_data.tar.gz
$cd treefam_family_data
 $egrep -a ">ENSP[0-9]+" *  | cut -d/ -f2 | tr -d : | sed -e 's/.aa.fasta//' |sed -e 's/.cds.fasta//' | grep -v accession | grep -v ^\> | tr '>' '\t' | tawk '{print $2,$1}' > ../ensToTreefam.tab 
$cd ..
# hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db ensGene knownGene knownToEnsembl -noLoad
#awk '{print $2,$1}' ../knownToEnsembl.tab | sort | uniq > ensTransUcsc.tab
$hgsql $db -e "select value,name from knownToEnsembl" | sort | uniq > ensTransUcsc.tab
$echo "select transcript,protein from ensGtp" | hgsql hg38 | sort | uniq | awk '{if (NF==2) print}'  > ensTransProt.tab
$join ensTransUcsc.tab ensTransProt.tab | awk '{if (NF==3)print $3, $2}' | sort | uniq  > ensProtToUc.tab
$join ensProtToUc.tab ensToTreefam.tab | sort -u | awk 'BEGIN {OFS="\t"} {print $2,$3}' | sort -u > knownToTreefam.tab
$hgLoadSqlTab $tempDb knownToTreefam $kent/src/hg/lib/knownTo.sql knownToTreefam.tab
#end not done

if ($db =~ hg*) then
    # TODO
    #hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db HInvGeneMrna knownGene knownToHInv
    #hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db affyU133Plus2 knownGene knownToU133Plus2
    hgMapToGene -tempDb=$tempDb $db affyU133 knownGene knownToU133
    hgMapToGene -tempDb=$tempDb $db affyU95 knownGene knownToU95
    mkdir hprd
    cd hprd
    wget "http://www.hprd.org/edownload/HPRD_FLAT_FILES_041310"
    tar xvf HPRD_FLAT_FILES_041310
    knownToHprd $tempDb FLAT_FILES_072010/HPRD_ID_MAPPINGS.txt
#    hgsql $tempDb -e "delete k from knownToHprd k, kgXref x where k.name = x.kgID and x.geneSymbol = 'abParts'"
endif

if ($db =~ hg*) then
    cd $dir
    time hgExpDistance $tempDb hgFixed.gnfHumanU95MedianRatio \
	    hgFixed.gnfHumanU95Exps gnfU95Distance  -lookup=knownToU95
    time hgExpDistance $tempDb hgFixed.gnfHumanAtlas2MedianRatio \
	hgFixed.gnfHumanAtlas2MedianExps gnfAtlas2Distance \
	-lookup=knownToGnfAtlas2
endif

if ($db =~ mm*) then
    hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db affyGnf1m knownGene knownToGnf1m
    hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db gnfAtlas2 knownGene knownToGnfAtlas2 '-type=bed 12'
    hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db affyU74  knownGene knownToU74
    hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db affyMOE430 knownGene knownToMOE430
    hgMapToGene -exclude=abGenes.txt -tempDb=$tempDb $db affyMOE430 -prefix=A: knownGene knownToMOE430A
    hgExpDistance $tempDb $db.affyGnfU74A affyGnfU74AExps affyGnfU74ADistance -lookup=knownToU74
    hgExpDistance $tempDb $db.affyGnfU74B affyGnfU74BExps affyGnfU74BDistance -lookup=knownToU74
    hgExpDistance $tempDb $db.affyGnfU74C affyGnfU74CExps affyGnfU74CDistance -lookup=knownToU74
    hgExpDistance $tempDb hgFixed.gnfMouseAtlas2MedianRatio \
	    hgFixed.gnfMouseAtlas2MedianExps gnfAtlas2Distance -lookup=knownToGnf1m
endif


cd $dir 

# Create Human P2P protein-interaction Gene Sorter columns
if ($db =~ hg*) then
hgLoadNetDist $genomes/hg19/p2p/hprd/hprd.pathLengths $tempDb humanHprdP2P \
    -sqlRemap="select distinct value, name from knownToHprd"
hgLoadNetDist $genomes/hg19/p2p/vidal/humanVidal.pathLengths $tempDb humanVidalP2P -sqlRemap="select distinct locusLinkID, kgID from $db.refLink,kgXref where $db.refLink.mrnaAcc = kgXref.mRNA"
hgLoadNetDist $genomes/hg19/p2p/wanker/humanWanker.pathLengths $tempDb humanWankerP2P -sqlRemap="select distinct locusLinkID, kgID from $db.refLink,kgXref where $db.refLink.mrnaAcc = kgXref.mRNA"
endif


# Run nice Perl script to make all protein blast runs for
# Gene Sorter and Known Genes details page.  Takes about
# 45 minutes to run.
rm -rf   $dir/hgNearBlastp
mkdir  $dir/hgNearBlastp
cd $dir/hgNearBlastp
tcsh
cat << _EOF_ > config.ra
# Latest human vs. other Gene Sorter orgs:
# mouse, rat, zebrafish, worm, yeast, fly

targetGenesetPrefix known
targetDb $tempDb
queryDbs $xdb $ratDb $fishDb $flyDb $wormDb $yeastDb

${tempDb}Fa $tempFa
${xdb}Fa $xdbFa
${ratDb}Fa $ratFa
${fishDb}Fa $fishFa
${flyDb}Fa $flyFa
${wormDb}Fa $wormFa
${yeastDb}Fa $yeastFa

buildDir $dir/hgNearBlastp
scratchDir $scratchDir/brHgNearBlastp
_EOF_

# exit tcsh

rm -rf  $scratchDir/brHgNearBlastp
doHgNearBlastp.pl -noLoad -clusterHub=ku -distrHost=hgwdev -dbHost=hgwdev -workhorse=hgwdev config.ra |& tee do.log 

# Load self
cd $dir/hgNearBlastp/run.$tempDb.$tempDb
./loadPairwise.csh

# Load mouse and rat
cd $dir/hgNearBlastp/run.$tempDb.$xdb
hgLoadBlastTab $tempDb $xBlastTab -maxPer=1 out/*.tab
cd $dir/hgNearBlastp/run.$tempDb.$ratDb
hgLoadBlastTab $tempDb $rnBlastTab -maxPer=1 out/*.tab

# Remove non-syntenic hits for mouse and rat
# Takes a few minutes
# TODO stopped here... need hg38 to rn4
mkdir -p /gbdb/$tempDb/liftOver
rm -f /gbdb/$tempDb/liftOver/${tempDb}To$RatDb.over.chain.gz /gbdb/$tempDb/liftOver/${tempDb}To$Xdb.over.chain.gz
ln -s $genomes/$db/bed/liftOver/${db}To$RatDb.over.chain.gz \
    /gbdb/$tempDb/liftOver/${tempDb}To$RatDb.over.chain.gz
ln -s $genomes/$db/bed/liftOver/${db}To${Xdb}.over.chain.gz \
    /gbdb/$tempDb/liftOver/${tempDb}To$Xdb.over.chain.gz

# delete non-syntenic genes from rat and mouse blastp tables
cd $dir/hgNearBlastp
synBlastp.csh $tempDb $xdb
# old number of unique query values:  65755
# old number of unique target values  22343
# new number of unique query values:  60984
# new number of unique target values  21844
#

hgsql -e "select  count(*) from mmBlastTab\G" $oldDb | tail -n +2
# count(*): 72823
hgsql -e "select  count(*) from mmBlastTab\G" $tempDb | tail -n +2
# count(*): 60984

synBlastp.csh $tempDb $ratDb knownGene rgdGene2
# old number of unique query values: 58734
# old number of unique target values 10138
# new number of unique query values: 31066
# new number of unique target values 7689

hgsql -e "select  count(*) from rnBlastTab\G" $oldDb | tail -n +2
# count(*): 28372
hgsql -e "select  count(*) from rnBlastTab\G" $tempDb | tail -n +2
# count(*): 31066

# Make reciprocal best subset for the blastp pairs that are too
# Far for synteny to help

# Us vs. fish
cd $dir/hgNearBlastp
export aToB=run.$tempDb.$fishDb
export bToA=run.$fishDb.$tempDb
cat $aToB/out/*.tab > $aToB/all.tab
cat $bToA/out/*.tab > $bToA/all.tab
blastRecipBest $aToB/all.tab $bToA/all.tab $aToB/recipBest.tab $bToA/recipBest.tab
hgLoadBlastTab $tempDb drBlastTab $aToB/recipBest.tab

hgsql -e "select  count(*) from drBlastTab\G" $oldDb | tail -n +2
# count(*): 13111
hgsql -e "select  count(*) from drBlastTab\G" $tempDb | tail -n +2
# count(*): 13031

# Us vs. fly
cd $dir/hgNearBlastp
export aToB=run.$tempDb.$flyDb
export bToA=run.$flyDb.$tempDb
cat $aToB/out/*.tab > $aToB/all.tab
cat $bToA/out/*.tab > $bToA/all.tab
blastRecipBest $aToB/all.tab $bToA/all.tab $aToB/recipBest.tab $bToA/recipBest.tab
hgLoadBlastTab $tempDb dmBlastTab $aToB/recipBest.tab

hgsql -e "select  count(*) from dmBlastTab\G" $oldDb | tail -n +2
#  count(*): 5975
hgsql -e "select  count(*) from dmBlastTab\G" $tempDb | tail -n +2
# count(*): 5974

# Us vs. worm
cd $dir/hgNearBlastp
export aToB=run.$tempDb.$wormDb
export bToA=run.$wormDb.$tempDb
cat $aToB/out/*.tab > $aToB/all.tab
cat $bToA/out/*.tab > $bToA/all.tab
blastRecipBest $aToB/all.tab $bToA/all.tab $aToB/recipBest.tab $bToA/recipBest.tab
hgLoadBlastTab $tempDb ceBlastTab $aToB/recipBest.tab

hgsql -e "select  count(*) from ceBlastTab\G" $oldDb | tail -n +2
# count(*): 4948
hgsql -e "select  count(*) from ceBlastTab\G" $tempDb | tail -n +2
# count(*): 4950

# Us vs. yeast
cd $dir/hgNearBlastp
export aToB=run.$tempDb.$yeastDb
export bToA=run.$yeastDb.$tempDb
cat $aToB/out/*.tab > $aToB/all.tab
cat $bToA/out/*.tab > $bToA/all.tab
blastRecipBest $aToB/all.tab $bToA/all.tab $aToB/recipBest.tab $bToA/recipBest.tab
hgLoadBlastTab $tempDb scBlastTab $aToB/recipBest.tab

hgsql -e "select  count(*) from scBlastTab\G" $oldDb | tail -n +2
# count(*): 2365
hgsql -e "select  count(*) from scBlastTab\G" $tempDb | tail -n +2
# count(*): 2366

# Clean up
cd $dir/hgNearBlastp
cat run.$tempDb.$tempDb/out/*.tab | gzip -c > run.$tempDb.$tempDb/all.tab.gz
gzip run.*/all.tab
#end didn't do

# make knownToMalacards
mkdir -p $dir/malacards
cd $dir/malacards
# grab files that b0b came up with somehow
cp /hive/users/kuhn/tracks/malacards/malacardsUcscGenesExport.csv .
awk 'BEGIN {FS=","} {print $1}' malacardsUcscGenesExport.csv | sort -u > malacardExists.txt
hgsql -e "select geneSymbol,kgId from kgXref" --skip-column-names hg38 | awk '{if (NF == 2) print}' | sort > geneSymbolToKgId.txt
join malacardExists.txt geneSymbolToKgId.txt | awk 'BEGIN {OFS="\t"} {print $2,$1}' | sort > knownToMalacards.tab
hgLoadSqlTab -notOnServer $tempDb  knownToMalacards $kent/src/hg/lib/knownTo.sql  knownToMalacards.tab

# make knownToLynx
mkdir -p $dir/lynx
cd $dir/lynx

wget "http://lynx.ci.uchicago.edu/downloads/LYNX_GENES.tab"
awk '{print $2}' LYNX_GENES.tab | sort > lynxExists.txt
hgsql -e "select geneSymbol,kgId from kgXref" --skip-column-names hg38 | awk '{if (NF == 2) print}' | sort > geneSymbolToKgId.txt
join lynxExists.txt geneSymbolToKgId.txt | awk 'BEGIN {OFS="\t"} {print $2,$1}' | sort > knownToLynx.tab
hgLoadSqlTab -notOnServer $tempDb  knownToLynx $kent/src/hg/lib/knownTo.sql  knownToLynx.tab

# make knownToNextProt
mkdir -p $dir/nextProt
cd $dir/nextProt

wget "ftp://ftp.nextprot.org/pub/current_release/ac_lists/nextprot_ac_list_all.txt"
awk '{print $0, $0}' nextprot_ac_list_all.txt | sed 's/NX_//' | sort > displayIdToNextProt.txt
hgsql -e "select spID,kgId from kgXref" --skip-column-names hg38 | awk '{if (NF == 2) print}' | sort > displayIdToKgId.txt
join displayIdToKgId.txt displayIdToNextProt.txt | awk 'BEGIN {OFS="\t"} {print $2,$3}' > knownToNextProt.tab
hgLoadSqlTab -notOnServer $tempDb  knownToNextProt $kent/src/hg/lib/knownTo.sql  knownToNextProt.tab


# make knownToWikipedia
# TODO  didn't doneeds a refresh...probably using Entrez.
mkdir -p $dir/wikipedia
cd $dir/wikipedia
hgsql hg19 -e "select * from knownToWikipedia" | tail -n +2 | sort > oldKnownToWikipedia.tab
hgsql hg38 -e "select oldId,newId from kg7ToKg8" | tail -n +2 | sort > kg7ToKg8.tab
join kg7ToKg8.tab oldKnownToWikipedia.tab | awk 'BEGIN {OFS="\t"} {print $2,$3}' | sort | uniq | awk '{if ((NF == 2) && (haveSeen[$1] == 0)) print;haveSeen[$1]=1}' > knownToWikipedia.tab
hgLoadSqlTab $tempDb  knownToWikipedia $kent/src/hg/lib/knownToWikipedia.sql  knownToWikipedia.tab
#end didn't do

# MAKE FOLDUTR TABLES 
# First set up directory structure and extract UTR sequence on hgwdev
# TODO, doesn't work with tmpFoo1  (nibPath is NULL)
tempDb=braNey38
cd $dir
mkdir -p rnaStruct
cd rnaStruct
mkdir -p utr3/split utr5/split utr3/fold utr5/fold
# these commands take some significant time
utrFa $tempDb knownGene utr3 utr3/utr.fa
utrFa $tempDb knownGene utr5 utr5/utr.fa

# Split up files and make files that define job.
faSplit sequence utr3/utr.fa 10000 utr3/split/s
faSplit sequence utr5/utr.fa 10000 utr5/split/s
ls -1 utr3/split > utr3/in.lst
ls -1 utr5/split > utr5/in.lst
cd utr3
cat << _EOF_ > template
#LOOP
rnaFoldBig split/$(path1) fold
#ENDLOOP
_EOF_
gensub2 in.lst single template jobList
cp template ../utr5
cd ../utr5

gensub2 in.lst single template jobList

# Do cluster runs for UTRs
ssh $cpuFarm "cd $dir/rnaStruct/utr3; para make jobList"
ssh $cpuFarm "cd $dir/rnaStruct/utr5; para make jobList"


# Load database
    cd $dir/rnaStruct/utr5
    hgLoadRnaFold $tempDb foldUtr5 fold
    cd ../utr3
    hgLoadRnaFold -warnEmpty $tempDb foldUtr3 fold

# Clean up
    rm -r split fold err batch.bak
    cd ../utr5
    rm -r split fold err batch.bak

# Make pfam run.  Actual cluster run is about 6 hours.
#mkdir -p /hive/data/outside/pfam/Pfam27.0
#cd /hive/data/outside/pfam/Pfam27.0
#wget ftp://ftp.sanger.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
#gunzip Pfam-A.hmm.gz
#set pfamScratch = $scratchDir/pfamBR
#ssh $cpuFarm mkdir -p $pfamScratch
#ssh $cpuFarm cp /hive/data/outside/pfam/Pfam26.0/Pfam-A.hmm $pfamScratch

mkdir -p $dir/pfam
cd $dir/pfam
rm -rf  splitProt
mkdir  splitProt
faSplit sequence $dir/ucscGenes.faa 10000 splitProt/
mkdir -p result
ls -1 splitProt > prot.list
# /hive/data/outside/pfam/hmmpfam -E 0.1 /hive/data/outside/pfam/current/Pfam_fs \
cat << '_EOF_' > doPfam
#!/bin/csh -ef  
/hive/data/outside/pfam/Pfam27.0/PfamScan/hmmer-3.1b1/src/hmmsearch   --domtblout /scratch/tmp/pfam.$2.pf --noali -o /dev/null -E 0.1 /hive/data/outside/pfam/Pfam27.0/Pfam-A.hmm     splitProt/$1 
mv /scratch/tmp/pfam.$2.pf $3
_EOF_
    # << happy emacs
chmod +x doPfam
cat << '_EOF_' > template
#LOOP
doPfam $(path1) $(root1) {check out line+ result/$(root1).pf}
#ENDLOOP
_EOF_
gensub2 prot.list single template jobList

ssh $cpuFarm "cd $dir/pfam; para make jobList"
ssh $cpuFarm "cd $dir/pfam; para time > run.time"
cat run.time

# Completed: 9577 of 9577 jobs
# CPU time in finished jobs:    1898828s   31647.13m   527.45h   21.98d  0.060 y
# IO & Wait Time:                823666s   13727.77m   228.80h    9.53d  0.026 y
# Average job time:                 284s       4.74m     0.08h    0.00d
# Longest finished job:             355s       5.92m     0.10h    0.00d
# Submission to last job:          9639s     160.65m     2.68h    0.11d

# Make up pfamDesc.tab by converting pfam to a ra file first
cat << '_EOF_' > makePfamRa.awk
/^NAME/ {print}
/^ACC/ {print}
/^DESC/ {print; printf("\n");}
_EOF_
awk -f makePfamRa.awk  /hive/data/outside/pfam/Pfam27.0/Pfam-A.hmm  > pfamDesc.ra
raToTab -cols=ACC,NAME,DESC pfamDesc.ra stdout |  awk -F '\t' '{printf("%s\t%s\t%s\n", gensub(/\.[0-9]+/, "", "g", $1), $2, $3);}' > pfamDesc.tab

# Convert output to tab-separated file. 
cd $dir/pfam
catDir result | sed '/^#/d' | awk 'BEGIN {OFS="\t"} {if ($7 < 0.0001) print $1,$18-1,$19,$4,$7}' | sort > ucscPfam.tab
cd $dir

# Convert output to knownToPfam table
awk '{printf("%s\t%s\n", $2, gensub(/\.[0-9]+/, "", "g", $1));}' \
	pfam/pfamDesc.tab > sub.tab
cut -f 1,4 pfam/ucscPfam.tab | subColumn 2 stdin sub.tab stdout | sort -u > knownToPfam.tab
rm -f sub.tab
hgLoadSqlTab -notOnServer $tempDb knownToPfam $kent/src/hg/lib/knownTo.sql knownToPfam.tab
hgLoadSqlTab -notOnServer $tempDb pfamDesc $kent/src/hg/lib/pfamDesc.sql pfam/pfamDesc.tab
#hgsql $tempDb -e "delete k from knownToPfam k, kgXref x where k.name = x.kgID and x.geneSymbol = 'abParts'"

cd $dir/pfam
genePredToFakePsl hg38 knownGene knownGene.psl cdsOut.tab
sort cdsOut.tab | sed 's/\.\./   /' > sortCdsOut.tab
sort ucscPfam.tab> sortPfam.tab
awk '{print $10, $11}' knownGene.psl > gene.sizes
join sortCdsOut.tab sortPfam.tab |  awk '{print $1, $2 + 3 * $4, $2 + 3 * $5, $6}' | bedToPsl gene.sizes stdin domainToGene.psl
pslMap domainToGene.psl knownGene.psl stdout | sort | uniq | pslToBed stdin domainToGenome.bed 
hgLoadBed $tempDb ucscGenePfam domainToGenome.bed

# Do scop run. Takes about 6 hours
mkdir /hive/data/outside/scop/1.75
cd /hive/data/outside/scop/1.75
wget "ftp://license:SlithyToves@supfam.org/models/hmmlib_1.75.gz"
gunzip hmmlib_1.75.gz
wget "ftp://license:SlithyToves@supfam.org/models/model.tab.gz"
gunzip model.tab.gz

mkdir -p $dir/scop
cd $dir/scop
rm -rf result
mkdir  result
ls -1 ../pfam/splitProt > prot.list
cat << '_EOF_' > doScop
#!/bin/csh -ef
/hive/data/outside/pfam/Pfam27.0/PfamScan/hmmer-3.1b1/src/hmmsearch   --domtblout /scratch/tmp/scop.$2.pf --noali -o /dev/null -E 0.1 /hive/data/outside/scop/1.75/hmmlib_1.75  ../pfam/splitProt/$1
mv /scratch/tmp/scop.$2.pf $3
_EOF_
    # << happy emacs
chmod +x doScop
cat << '_EOF_' > template
#LOOP
doScop $(path1) $(root1) {check out line+ result/$(root1).pf}
#ENDLOOP
_EOF_
    # << happy emacs
gensub2 prot.list single template jobList

ssh $cpuFarm "cd $dir/scop; para make jobList"
ssh $cpuFarm "cd $dir/scop; para time > run.time"
cat run.time

# Completed: 9577 of 9577 jobs
# CPU time in finished jobs:    1872212s   31203.54m   520.06h   21.67d  0.059 y
# IO & Wait Time:                904637s   15077.28m   251.29h   10.47d  0.029 y
# Average job time:                 290s       4.83m     0.08h    0.00d
# Longest finished job:             664s      11.07m     0.18h    0.01d
# Submission to last job:         10541s     175.68m     2.93h    0.12d

# Convert scop output to tab-separated files
cd $dir
catDir scop/result | sed '/^#/d' | awk 'BEGIN {OFS="\t"} {if ($7 <= 0.0001) print $1,$18-1,$19,$4, $7,$8}' | sort > scopPlusScore.tab
sort -k 2 /hive/data/outside/scop/1.75/model.tab > scop.model.tab
scopCollapse scopPlusScore.tab scop.model.tab ucscScop.tab \
	scopDesc.tab knownToSuper.tab
hgLoadSqlTab -notOnServer $tempDb scopDesc $kent/src/hg/lib/scopDesc.sql scopDesc.tab
hgLoadSqlTab $tempDb knownToSuper $kent/src/hg/lib/knownToSuper.sql knownToSuper.tab
#hgsql $tempDb -e "delete k from knownToSuper k, kgXref x where k.gene = x.kgID and x.geneSymbol = 'abParts'"

hgLoadSqlTab $tempDb ucscScop $kent/src/hg/lib/ucscScop.sql ucscScop.tab

# Regenerate ccdsKgMap table
# TODO: didn't do
$kent/src/hg/makeDb/genbank/bin/x86_64/mkCcdsGeneMap  -db=$tempDb -loadDb $db.ccdsGene knownGene ccdsKgMap


# Do BioCyc Pathways build
export bioCycDir=/hive/data/outside/bioCyc/140219/download/17.5/data
mkdir $dir/bioCyc
cd $dir/bioCyc

grep -E -v "^#" $bioCycDir/genes.col  > genes.tab  
grep -E -v "^#" $bioCycDir/pathways.col  | awk -F'\t' '{if (140 == NF) { printf "%s\t\t\n", $0; } else { print $0}}' > pathways.tab

kgBioCyc1 -noEnsembl genes.tab pathways.tab hg38 bioCycPathway.tab bioCycMapDesc.tab  
hgLoadSqlTab $tempDb bioCycPathway ~/kent/src/hg/lib/bioCycPathway.sql ./bioCycPathway.tab
hgLoadSqlTab $tempDb bioCycMapDesc ~/kent/src/hg/lib/bioCycMapDesc.sql ./bioCycMapDesc.tab

# Do KEGG Pathways build (borrowing Fan Hus's strategy from hg38.txt)
    mkdir -p $dir/kegg
    cd $dir/kegg

    # Make the keggMapDesc table, which maps KEGG pathway IDs to descriptive names
    cp /cluster/data/hg19/bed/ucsc.13/kegg/map_title.tab .
    # wget --timestamping ftp://ftp.genome.jp/pub/kegg/pathway/map_title.tab
    cat map_title.tab | sed -e 's/\t/\thsa\t/' > j.tmp
    cut -f 2 j.tmp >j.hsa
    cut -f 1,3 j.tmp >j.1
    paste j.hsa j.1 |sed -e 's/\t//' > keggMapDesc.tab
    rm j.hsa j.1 j.tmp
    hgLoadSqlTab -notOnServer $tempDb keggMapDesc $kent/src/hg/lib/keggMapDesc.sql keggMapDesc.tab

    # Following in two-step process, build/load a table that maps UCSC Gene IDs
    # to LocusLink IDs and to KEGG pathways.  First, make a table that maps 
    # LocusLink IDs to KEGG pathways from the downloaded data.  Store it temporarily
    # in the keggPathway table, overloading the schema.
    cp /cluster/data/hg19/bed/ucsc.14.3/kegg/hsa_pathway.list .

    cat hsa_pathway.list| sed -e 's/path://'|sed -e 's/:/\t/' > j.tmp
    hgLoadSqlTab -notOnServer $tempDb keggPathway $kent/src/hg/lib/keggPathway.sql j.tmp

    # Next, use the temporary contents of the keggPathway table to join with
    # knownToLocusLink, creating the real content of the keggPathway table.
    # Load this data, erasing the old temporary content
    hgsql $tempDb -B -N -e 'select distinct name, locusID, mapID from keggPathway p, knownToLocusLink l where p.locusID=l.value' > keggPathway.tab
    hgLoadSqlTab -notOnServer $tempDb \
	keggPathway $kent/src/hg/lib/keggPathway.sql  keggPathway.tab

   # Finally, update the knownToKeggEntrez table from the keggPathway table.
   hgsql $tempDb -B -N -e 'select kgId, mapID, mapID, "+", locusID from keggPathway' |sort -u| sed -e 's/\t+\t/+/' > knownToKeggEntrez.tab
   hgLoadSqlTab -notOnServer $tempDb knownToKeggEntrez $kent/src/hg/lib/knownToKeggEntrez.sql knownToKeggEntrez.tab
    hgsql $tempDb -e "delete k from knownToKeggEntrez k, kgXref x where k.name = x.kgID and x.geneSymbol = 'abParts'"

# Make spMrna table 
   cd $dir
   hgsql $db -N -e "select spDisplayID,kgID from kgXref where spDisplayID != ''" > spMrna.tab;
   hgLoadSqlTab $tempDb spMrna $kent/src/hg/lib/spMrna.sql spMrna.tab


# Do CGAP tables 

    mkdir -p $dir/cgap
    cd $dir/cgap
    
    wget --timestamping -O Hs_GeneData.dat "ftp://ftp1.nci.nih.gov/pub/CGAP/Hs_GeneData.dat"
    hgCGAP Hs_GeneData.dat
        
    cat cgapSEQUENCE.tab cgapSYMBOL.tab cgapALIAS.tab|sort -u > cgapAlias.tab
    hgLoadSqlTab -notOnServer $tempDb cgapAlias $kent/src/hg/lib/cgapAlias.sql ./cgapAlias.tab

    hgLoadSqlTab -notOnServer $tempDb cgapBiocPathway $kent/src/hg/lib/cgapBiocPathway.sql ./cgapBIOCARTA.tab

    cat cgapBIOCARTAdesc.tab|sort -u > cgapBIOCARTAdescSorted.tab
    hgLoadSqlTab -notOnServer $tempDb cgapBiocDesc $kent/src/hg/lib/cgapBiocDesc.sql cgapBIOCARTAdescSorted.tab



cd $dir
# Make PCR target for UCSC Genes, Part 1.
# 1. Get a set of IDs that consist of the UCSC Gene accession concatenated with the
#    gene symbol, e.g. uc010nxr.1__DDX11L1
hgsql $tempDb -N -e 'select kgId,geneSymbol from kgXref' \
    | perl -wpe 's/^(\S+)\t(\S+)/$1\t${1}__$2/ || die;' \
      > idSub.txt 
# 2. Get a file of per-transcript fasta sequences that contain the sequences of each UCSC Genes transcript, with this new ID in the place of the UCSC Genes accession.   Convert that file to TwoBit format and soft-link it into /gbdb/hg38/targetDb/ 
subColumn 4 ucscGenes.bed idSub.txt ucscGenesIdSubbed.bed sequenceForBed -keepName -db=$db -bedIn=ucscGenesIdSubbed.bed -fastaOut=stdout  | faToTwoBit stdin kgTargetSeq${curVer}.2bit 
mkdir -p /gbdb/$db/targetDb/ 
rm -f /gbdb/$db/targetDb/kgTargetSeq${curVer}.2bit 
ln -s $dir/kgTargetSeq${curVer}.2bit /gbdb/$db/targetDb/
# Load the table kgTargetAli, which shows where in the genome these targets are.
cut -f 1-10 ucscGenes.gp | genePredToFakePsl $tempDb stdin kgTargetAli.psl /dev/null
hgLoadPsl $tempDb kgTargetAli.psl

#
# At this point we should save a list of the tables in tempDb!!!
echo "show tables" | hgsql $tempDb > tablesInKnownGene.lst

# got hg38.knownGene.tables.txt  from the last push request
hgsql $db -e "show tables like 'knownTo%'" | tail -n +2 | sort > hg38.knownTo.txt
join -v 1 hg38.knownTo.txt  hg38.knownGene.tables.txt 
#knownToGencodeV20
#knownToGnf1h
#knownToGnfAtlas2
#knownToMalacards
#knownToU133
#knownToU95
cat hg38.knownTo.txt hg38.knownGene.tables.txt | sort -u > hg38.all.knownGene.tables.txt
# added ccdsKgMap gnfAtlas2Distance gnfU95Distance

for i in  `cat hg38.all.knownGene.tables.txt`; do echo "desc $i;" | hgsql $tempDb; done 2>&1 | grep exist | awk '{print $8}' > missing.tables.txt

join -v 1 tablesInKnownGene.lst hg38.all.knownGene.tables.txt
# kg8ToKg9
# kgXrefOld8
# knownGeneOld8
# knownToEnsembl
# knownToGencodeV22
# knownToMrna
# knownToMrnaSingle
# knownToTag

join -v 2 tablesInKnownGene.lst hg38.all.knownGene.tables.txt
#kg7ToKg8
#kgProtMap2
#kgTxInfo
#knownGeneTxMrna
#knownGeneTxPep
#knownToGencodeV20
#knownToGnf1h
#knownToWikipedia

# Create backup database
hgsqladmin create ${db}Backup

# Swap in new tables, moving old tables to backup database.
for i in  `cat hg38.all.knownGene.tables.txt`
do
echo "rename table $db.$i to ${db}Backup.$i;" | hgsql $db;
done

for i in  `cat tablesInKnownGene.lst`
do
echo "rename table $tempDb.$i to ${db}.$i;"  | hgsql $db
done


hgsqladmin flush-tables

# Make full text index.  Takes a minute or so.  After this the genome browser
# tracks display will work including the position search.  The genes details

# NOW SWAP IN TABLES FROM TEMP DATABASE TO MAIN DATABASE.
# You'll need superuser powers for this step.....

cd $dir
# Drop tempDb history table and chromInfo, we don't want to swap them in!
hgsql -e "drop table history" $tempDb
hgsql -e "drop table chromInfo" $tempDb


cat << _EOF_ > moveTablesIntoPlace
# Save old known genes and kgXref tables
sudo ~kent/bin/copyMysqlTable $db knownGene $tempDb knownGeneOld$lastVer
sudo ~kent/bin/copyMysqlTable $db kgXref $tempDb kgXrefOld$lastVer

# Create backup database
hgsqladmin create ${db}BackupBraney2


# Swap in new tables, moving old tables to backup database.
sudo ~kent/bin/swapInMysqlTempDb $tempDb $db ${db}BackupBraney2
_EOF_


# Update database links.
sudo rm /var/lib/mysql/uniProt
sudo ln -s /var/lib/mysql/$spDb /var/lib/mysql/uniProt
sudo rm /var/lib/mysql/proteome
sudo ln -s /var/lib/mysql/$pbDb /var/lib/mysql/proteome
hgsqladmin flush-tables


# Make full text index.  Takes a minute or so.  After this the genome browser
# tracks display will work including the position search.  The genes details
# page, gene sorter, and proteome browser still need more tables.
mkdir -p $dir/index
cd $dir/index
hgKgGetText $db knownGene.text 
ixIxx knownGene.text knownGene.ix knownGene.ixx
rm -f /gbdb/$db/knownGene.ix /gbdb/$db/knownGene.ixx
ln -s $dir/index/knownGene.ix  /gbdb/$db/knownGene.ix
ln -s $dir/index/knownGene.ixx /gbdb/$db/knownGene.ixx


# 3. Ask cluster-admin to start an untranslated, -stepSize=5 gfServer on       
# /gbdb/$db/targetDb/kgTargetSeq${curVer}.2bit

# 4. On hgwdev, insert new records into blatServers and targetDb, using the 
# host (field 2) and port (field 3) specified by cluster-admin.  Identify the
# blatServer by the keyword "$db"Kg with the version number appended
hgsql hgcentraltest -e \
      'INSERT into blatServers values ("hg38Kgv15", "blat4b", 17787, 0, 1);'
hgsql hgcentraltest -e \                                                    
      'INSERT into targetDb values("hg38Kgv15", "UCSC Genes", \
         "hg38", "kgTargetAli", "", "", \
         "/gbdb/hg38/targetDb/kgTargetSeq8.2bit", 1, now(), "");'

#
##
##   WRAP-UP  
#
#  add database to the db's in kent/src/hg/visiGene/vgGetText

cd $dir
#
# Finally, need to wait until after testing, but update databases in other organisms
# with blastTabs

# Load blastTabs
cd $dir/hgNearBlastp
hgLoadBlastTab $xdb $blastTab run.$xdb.$tempDb/out/*.tab
hgLoadBlastTab $ratDb $blastTab run.$ratDb.$tempDb/out/*.tab 
hgLoadBlastTab $flyDb $blastTab run.$flyDb.$tempDb/recipBest.tab
hgLoadBlastTab $wormDb $blastTab run.$wormDb.$tempDb/recipBest.tab
hgLoadBlastTab $yeastDb $blastTab run.$yeastDb.$tempDb/recipBest.tab

# Do synteny on mouse/human/rat
synBlastp.csh $xdb $db
# old number of unique query values: 43110
# old number of unique target values 22769
# new number of unique query values: 35140
# new number of unique target values 20138

synBlastp.csh $ratDb $db rgdGene2 knownGene
#old number of unique query values: 11205
#old number of unique target values 10791
#new number of unique query values: 7854
#new number of unique target values 7935

# need to generate multiz downloads
#/usr/local/apache/htdocs-hgdownload/goldenPath/hg38/multiz46way/alignments/knownCanonical.exonAA.fa.gz
#/usr/local/apache/htdocs-hgdownload/goldenPath/hg38/multiz46way/alignments/knownCanonical.exonNuc.fa.gz
#/usr/local/apache/htdocs-hgdownload/goldenPath/hg38/multiz46way/alignments/knownGene.exonAA.fa.gz
#/usr/local/apache/htdocs-hgdownload/goldenPath/hg38/multiz46way/alignments/knownGene.exonNuc.fa.gz
#/usr/local/apache/htdocs-hgdownload/goldenPath/hg38/multiz46way/alignments/md5sum.txt

echo
echo "see the bottom of the script for details about knownToWikipedia"
echo
# Clean up
rm -r run.*/out

# Last step in setting up isPCR: after the new UCSC Genes with the new Known Gene isPcr
# is released, take down the old isPcr gfServer  

#######################
### The following is the process Briam Lee used to pull out only
#   the genes from knownToLocusLink for which there are Wikipedia articles.
### get the full knownToLocusLinkTable
# hgsql -Ne 'select value from knownToLocusLink' hg38 | sort -u >> knToLocusLink
###   query Wikipedia for each to if there is an article
# for i in $(cat knToLocusLink); do lynx -dump "http://api.genewikiplus.org/biogps-plugins/wp/"$i | grep -m 1 "no results" >trash ; echo $? $i | grep "1 "| awk '{print $2}'>> workingLinks; done
###   pull out all isoforms that have permitted LocusLinkIds
# for i in $(cat workingLinks); do hgsql -Ne 'select * from knownToLocusLink where value like "'$i'"' hg38 >> knownToWikipediaNew; done
###   then load the table as knownToWikipedia using the knowToLocusLink INDICES.

