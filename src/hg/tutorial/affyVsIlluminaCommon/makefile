include ../../../inc/common.mk

L += $(MYSQLLIBS) -lm
MYLIBDIR = ../../../lib/${MACHTYPE}
MYLIBS =  $(MYLIBDIR)/jkhgap.a ${MYLIBDIR}/jkweb.a

O = affyVsIlluminaCommon.o

affyVsIlluminaCommon: $O ${MYLIBS}
	${CC} ${COPT} -o ${BINDIR}/affyVsIlluminaCommon $O ${MYLIBS} $L
	${STRIP} ${BINDIR}/affyVsIlluminaCommon${EXE}

clean:
	rm -f $O
