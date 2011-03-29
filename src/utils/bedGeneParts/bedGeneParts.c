/* bedGeneParts - Given a bed, spit out promoter, first exon, or all introns.. */
#include "common.h"
#include "linefile.h"
#include "hash.h"
#include "options.h"
#include "basicBed.h"

static char const rcsid[] = "$Id: newProg.c,v 1.30 2010/03/24 21:18:33 hiram Exp $";

int proStart = -100;
int proEnd = 50;

void usage()
/* Explain usage and exit. */
{
errAbort(
  "bedGeneParts - Given a bed, spit out promoter, first exon, or all introns.\n"
  "usage:\n"
  "   bedGeneParts part in.bed out.bed\n"
  "Where part is either 'firstExon' or 'introns' or 'promoter'\n"
  "options:\n"
  "   -proStart=NN - start of promoter relative to txStart, default %d\n"
  "   -proEnd=NN - end of promoter relative to txStart, default %d\n"
  , proStart, proEnd
  );
}

static struct optionSpec options[] = {
   {"proStart", OPTION_INT},
   {"proEnd", OPTION_INT},
   {NULL, 0},
};

enum partChoice {pcFirstExon, pcIntrons, pcPromoter};

void bedGeneParts(char *part, char *input, char *output)
/* bedGeneParts - Given a bed, spit out promoter, first exon, or all introns.. */
{
/* Convert part string to an enum and make sure it's one we recognize. */
enum partChoice choice = pcFirstExon;
int minWords = 0;
if (sameString(part, "firstExon")) 
    {
    choice = pcFirstExon;
    minWords = 12;
    }
else if (sameString(part, "introns"))
    {
    choice = pcIntrons;
    minWords = 12;
    }
else if (sameString(part, "promoter"))
    {
    choice = pcPromoter;
    minWords = 6;
    }
else
    errAbort("Unrecognized part '%s'", part);

struct lineFile *lf = lineFileOpen(input, TRUE);
FILE *f = mustOpen(output, "w");
char *words[256];
int wordCount;
while ((wordCount = lineFileChop(lf, words)) != 0)
    {
    lineFileExpectAtLeast(lf, minWords, wordCount);
    struct bed *bed = bedLoadN(words, wordCount);
    char strand = bed->strand[0];
    if (strand != '+' && strand != '-')
        errAbort("Unrecognized strand %c line %d of %s\n", strand, lf->lineIx, lf->fileName);
    int start,end;
    switch (choice)
        {
	case pcFirstExon:
	    {
	    if (strand == '+')
		{
	        start = bed->chromStart;
		end = start + bed->blockSizes[0];
		}
	    else
	        {
		end = bed->chromEnd;
		start = end - bed->blockSizes[bed->blockCount-1];
		}
	    fprintf(f, "%s\t%d\t%d\t%s\t%d\t%c\n", 
	    	bed->chrom, start, end, bed->name, bed->score, strand);
	    break;
	    }
	case pcIntrons:
	    {
	    if (bed->blockCount > 1)
	        {
		/* Figure out last block index and start/end of introns overall */
		int lastBlock = bed->blockCount-1;
		int start = bed->chromStart + bed->blockSizes[0];
		int end = bed->chromEnd - bed->blockSizes[lastBlock];
		
		/* Print out constant fields. */
		fprintf(f, "%s\t%d\t%d\t%s\t%d\t%c\t", 
		    bed->chrom, start, end, bed->name, bed->score, strand);
		fprintf(f, "%d\t%d\t%d\t%d\t", 
			start, end, bed->itemRgb, bed->blockCount-1);

	        /* Print out intron sizes. */
		int i;
		for (i=0; i<lastBlock; ++i)
		    {
		    int s = bed->chromStarts[i] + bed->blockSizes[i];
		    int e = bed->chromStarts[i+1];
		    fprintf(f, "%d,", e-s);
		    }
		fprintf(f, "\t");

		/* Print out intron starts. */
		for (i=0; i<lastBlock; ++i)
		     fprintf(f, "%d,", 
		     	bed->chromStart + bed->chromStarts[i] + bed->blockSizes[i] - start);
		fprintf(f, "\n");
		}
	    break;
	    }
	case pcPromoter:
	    {
	    if (strand == '+')
	        {
		start = bed->chromStart + proStart;
		end = bed->chromStart + proEnd;
		}
	    else
	        {
		start = bed->chromEnd - proEnd;
		end = bed->chromEnd - proStart;
		}
	    fprintf(f, "%s\t%d\t%d\t%s\t%d\t%c\n", 
	    	bed->chrom, start, end, bed->name, bed->score, strand);
	    break;
	    }
	}
    bedFree(&bed);
    }
}

int main(int argc, char *argv[])
/* Process command line. */
{
optionInit(&argc, argv, options);
if (argc != 4)
    usage();
proStart = optionInt("proStart", proStart);
proEnd = optionInt("proEnd", proEnd);
if (proStart >= proEnd)
   errAbort("proStart has to be before proEnd");
bedGeneParts(argv[1], argv[2], argv[3]);
return 0;
}