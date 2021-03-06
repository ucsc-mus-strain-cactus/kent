# set for preview 1: move date and vNNN from REVIEWDAY to LASTREVIEWDAY
setenv REVIEWDAY 2015-06-29             # v319 preview, increment vNNN and today
setenv LASTREVIEWDAY 2015-06-08         # v318 preview
# set for preview 2: move date and vNNN from REVIEW2DAY to LASTREVIEW2DAY
setenv REVIEW2DAY 2015-06-15        # v318 preview2, increment vNNN and today
setenv LASTREVIEW2DAY 2015-05-25    # v317 preview2
# set these three for final build:  move date and vNNN from TODAY to LASTWEEK
setenv BRANCHNN 318                    # increment for new build
setenv TODAY 2015-06-22                # v318 final, increment vNNN and today
setenv LASTWEEK 2015-06-01             # v317 final

setenv BUILDHOME /hive/groups/browser/newBuild
setenv WEEKLYBLD ${BUILDHOME}/kent/src/utils/qa/weeklybld
setenv REPLYTO ann@soe.ucsc.edu

setenv GITSHAREDREPO hgwdev.cse.ucsc.edu:/data/git/kent.git

# see also paths in kent/java/build.xml
setenv BUILDDIR $BUILDHOME
# must get static MYSQL libraries, not the dynamic ones from the auto configuration
setenv MYSQLINC /usr/include/mysql
setenv MYSQLLIBS /usr/lib64/mysql/libmysqlclient.a
setenv JAVABUILD /scratch/javaBuild
setenv JAVA_HOME /usr/java/default
setenv CLASSPATH .:/usr/share/java:/usr/java/default/jre/lib/rt.jar:/usr/java/default/jre/lib:/usr/share/java/httpunit.jar:/cluster/bin/java/jtidy.jar:/usr/share/java/rhino.jar:/cluster/bin/java/mysql-connector-java-3.0.16-ga-bin.jar
# java and ant wont run on hgwdev now without setting max memory
setenv _JAVA_OPTIONS "-Xmx1024m"

