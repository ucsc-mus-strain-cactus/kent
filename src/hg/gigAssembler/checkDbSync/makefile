include ../../../inc/common.mk


L += $(MYSQLLIBS) -lm 
MYLIBDIR = ../../../lib/$(MACHTYPE)
MYLIBS =  $(MYLIBDIR)/jkhgap.a $(MYLIBDIR)/jkweb.a


O = checkDbSync.o

checkDbSync: $(O)
	${CC} ${COPT} ${CFLAGS} -o ${BINDIR}/checkDbSync $O $(MYLIBS) $(L)
	${STRIP} ${BINDIR}/checkDbSync${EXE}

clean::
	rm -f ${O}
