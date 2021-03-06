#!/bin/bash

function displayHeader() {
	echo
	echo
	echo	
	echo ====================================================================
	echo == 
	echo == CSAP Tomcat: $*
	echo ==
	echo ====================================================================
	
}


function printIt() {
	echo;echo;
	echo = 
	echo = $*
	echo = 
}


packageDir=$STAGING/warDist/$csapName.secondary

function buildAdditionalPackages() {
	
	displayHeader buildAdditionalPackages: no additional packages to build

	
}

function getAdditionalBinaryPackages() {
	
	displayHeader getAdditionalBinaryPackages from $toolsServer
	
	printIt removing $packageDir
	\rm -rf $packageDir
	
	printIt Getting tomcat 7
	mkdir -p $packageDir/tom7
	cd $packageDir/tom7
	wget -nv http://$toolsServer/tomcat/tom7/apache-tomcat-7.0.68.tar.gz
	wget -nv http://$toolsServer/tomcat/tom7/catalina-jmx-remote.jar
	
	printIt Getting tomcat 8
	mkdir -p $packageDir/tom8
	cd $packageDir/tom8
	wget -nv http://$toolsServer/tomcat/tom8/apache-tomcat-8.0.35.tar.gz
	wget -nv http://$toolsServer/tomcat/tom8/catalina-jmx-remote.jar
	
	printIt Getting tomcat 8.5
	mkdir -p $packageDir/tom8.5
	cd $packageDir/tom8.5
	wget -nv http://$toolsServer/tomcat/tom8.5/apache-tomcat-8.5.16.tar.gz
	wget -nv http://$toolsServer/tomcat/tom8.5/catalina-jmx-remote.jar
	
	printIt Getting tomcat 9
	mkdir $packageDir/tom9
	cd $packageDir/tom9
	wget -nv http://$toolsServer/tomcat/tom9/apache-tomcat-9.0.0.M22.tar.gz
	wget -nv http://$toolsServer/tomcat/tom9/catalina-jmx-remote.jar
	
	printIt Getting cssp1
	mkdir $packageDir/cssp1
	cd $packageDir/cssp1
	wget -nv http://$toolsServer/tomcat/eol/cssp-1.0.25.zip
	
	printIt Getting cssp3
	mkdir $packageDir/cssp3
	cd $packageDir/cssp3
	wget -nv http://$toolsServer/tomcat/eol/cssp3-3.1.4.zip
	
		
}



function killWrapper() {

	
	displayHeader KILL - using default
	
}

function stopWrapper() {


	displayHeader STOP - using default
	
}

function setTarAndCpParams() {
	numSkipInDocs=`man tar | grep "silently skip" | wc -l`
	if [ $numSkipInDocs == 1 ] ; then 
		tarParams="--skip-old-files"
		cpParams="-n";
	else
		printIt WARNING - clobbering old files. EOL OS detected
		uname -a
		tarParams="";
		cpParams="-u";
	fi ;
}


function startWrapper() {
	
	tomcatExtract=$PROCESSING/appsTomcat
	
	displayHeader "Starting tomcat package. Binaries will be extracted to $tomcatExtract"
	
	
	if [ "$extractAsNeeded" != "true" ] ; then 
		
		printIt Extracting to $tomcatExtract. Note by default existing files are NOT overwritten 
	
	
		if [ ! -d $tomcatExtract ] ; then 
			mkdir -p  $tomcatExtract
		fi;
		
		cd $tomcatExtract

		# handle old OSs
		setTarAndCpParams
		
		printIt Extracting tom7 into $tomcatExtract 
		# set -x
		tar $tarParams -xzf $packageDir/tom7/*.gz
		addTomcatCustomizations tom7
		#set +x
		
		printIt Extracting tom8 into $tomcatExtract 
		tar $tarParams -xzf $packageDir/tom8/*.gz
		addTomcatCustomizations tom8
		
		printIt Extracting tom8.5 into $tomcatExtract 
		tar $tarParams -xzf $packageDir/tom8.5/*.gz
		addTomcatCustomizations tom8.5
		
		
		printIt Extracting tom9 into $tomcatExtract 
		tar $tarParams -xzf $packageDir/tom9/*.gz
		addTomcatCustomizations tom9
		
		
		printIt Extracting cssp1 into $tomcatExtract 
		unzip -uq $packageDir/cssp1/*.zip
		addTomcatCustomizations cssp1
		
		
		printIt Extracting cssp3 into $tomcatExtract 
		unzip -uq $packageDir/cssp3/*.zip
		addTomcatCustomizations cssp3
	
		
		printIt  chmod 755 $tomcatExtract
		chmod --quiet -R 755 $tomcatExtract 
		
	else
		printIt Only configured runtimes will be extracted	
	fi ;

}


	
function addTomcatCustomizations() {
	
	#tomcatRuntimeSetup
	if [ "$csapVanilla" != "true" ] ; then
		
		runtime="$1"
		customSource="unknownSrc"
		customDest="unknownDest/lib"
		case $runtime in
			tom7 ) 
				customSource="$packageDir/tom7"
				customDest=`ls -td $tomcatExtract/apache-tomcat-7* | head -1`
				;;
			cssp1 ) 
				customSource="$packageDir/tom7"
				customDest=`ls -td $tomcatExtract/cssp-1* | head -1`
				;;
				
			tom8 ) 
				customSource="$packageDir/tom8"
				customDest=`ls -td $tomcatExtract/apache-tomcat-8.0* | head -1`
				;;
				
			tom8.5 ) 
				customSource="$packageDir/tom8.5"
				customDest=`ls -td $tomcatExtract/apache-tomcat-8.5* | head -1`
				;;
				
			cssp3 ) 
				customSource="$packageDir/tom8"
				customDest=`ls -td $tomcatExtract/cssp3-* | head -1`
				;;
				
			tom9 ) 
				customSource="$packageDir/tom9"
				customDest=`ls -td $tomcatExtract/apache-tomcat-9* | head -1`
				;;
				
			* ) echo "unknown runtime: " $runtime
				;;
		esac;
		
	
		printIt WARNING: customizing $customDest, add csapVanilla environment variable to use vanilla tomcat
		
		addTomcatJmx customSource customDest
		
		addTomcatOracle
		
		printIt Info Updating $STAGING/bin/log4j.properties $customDest/lib
		\cp $cpParams  $STAGING/bin/log4j.properties $customDest/lib
		
		addTomcatInstanceCustom
	fi ;
	
}

function addTomcatInstanceCustom() {
	printIt Adding Tomcat Instance overrides to ensure security from $csapWorkingDir/custom/$runtime to  $customDest/custom
	mkdir $customDest/custom
	cp -r $cpParams $csapWorkingDir/custom/$runtime/* $customDest
}


function addTomcatJmx() {
	
	printIt Adding Tomcat JMX Firewall support jars from $customSource to  $customDest/lib
	
	cp $cpParams $customSource/*.jar $customDest/lib
	
}

	
function addTomcatOracle() {
	
	jdbcJar=ojdbc6_g.jar ;
	jdbcSource="$ORACLE_HOME/jdbc/lib/$jdbcJar" ;
	
	# override if we find other versions
	if [ -e $ORACLE_HOME/ojdbc7.jar ] ; then 
		jdbcJar=ojdbc7.jar ;
		jdbcSource="$ORACLE_HOME/$jdbcJar" ;
	elif [ -e $ORACLE_HOME/jdbc/lib/ojdbc6.jar ] ; then 
		jdbcJar=ojdbc6.jar ;
		jdbcSource="$ORACLE_HOME/jdbc/lib/$jdbcJar" ;
	elif [ -e $ORACLE_HOME/ojdbc6.jar ] ; then 
		jdbcJar=ojdbc6.jar ;
		jdbcSource="$ORACLE_HOME/$jdbcJar" ;
	elif [ -e $ORACLE_HOME/jdbc/lib/ojdbc14_g.jar ] ; then 
		jdbcJar=ojdbc14_g.jar ;
		jdbcSource="$ORACLE_HOME/jdbc/lib/$jdbcJar" ;
	elif [ -e $ORACLE_HOME/jdbc/lib/ojdbc14.jar ] ; then
		jdbcJar=ojdbc14_g.jar ;
		jdbcSource="$ORACLE_HOME/jdbc/lib/$jdbcJar" ;
	elif [ -e $ORACLE_HOME/ojdbc14.jar ] ; then
		jdbcJar=ojdbc14.jar ;
		jdbcSource="$ORACLE_HOME/$jdbcJar" ;
	else
		printIt ERROR:  Unable to locate jdbc driver in  $ORACLE_HOME, valide /home/ssadmin/.cafEnvOverride 
		echo ==
		echo == Start will continue, but functions may be impacted.
	fi ; 
	
	if [ ! -e $customDest/lib/$jdbcJar ] ; then 	
		printIt INFO: Adding $jdbcSource to $customDest/lib ============
		#echo  Did not find $CATALINA_HOME/lib/$jdbcJar
		# echo getting rid of any previous versions
		# \rm -rf ojdbc?.jar
		\cp $cpParams $jdbcSource  $customDest/lib
		
		
	else 
		echo info only: Oracle Driver found in shared runtime 
	fi
	
}

