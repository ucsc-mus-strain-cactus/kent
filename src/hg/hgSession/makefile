include ../../inc/common.mk

L += -lm ${MYSQLLIBS}
MYLIBDIR = ../../lib/${MACHTYPE}
MYLIBS =  ${MYLIBDIR}/jkhgap.a ${MYLIBDIR}/jkweb.a

A = hgSession

O = $A.o

include ../../inc/cgi_build_rules.mk

compile: $O 
	${CC} -o $A${EXE} -g $O ${MYLIBS} ${L} 

