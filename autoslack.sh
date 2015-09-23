#!/bin/bash
#AutoSlack
#to grab a package from slackbuilds just type at your prompt 
#>autoslack $packagename 
#$packagename can be in any case whatsover, since this does do
#some rudimentary fuzzy matching. This also resolves dependencies
#the "Unix way". (Not really, it's just terrible coding, and potentially
#has the possibility of spawning infinite autoslacks. Autoslack fhtagn!

scriptversion="0.99x"
SLAURL="rsync://slackbuilds.org/slackbuilds/14.1/SLACKBUILDS.TXT"
URPREFIX="rsync://slackbuilds.org/slackbuilds/14.1"
BUILDPREFIX="/tmp"
SLACKBUILDS=/usr/share/autoslack/SLACKBUILDS.TXT
SLACKRCHIVE=/usr/share/autoslack/packages/
parseslack=0

preprerun () {
    if [[ $packagename =~ ^$ ]]; then	
	echo "You did not select any packages to install, exiting" 
	exit 0
    else
	echo "installing $packagename"
	logfile=$(echo $packagename-`date +%d_%m_%y`.log)
    fi
}

grabslackbuild () {
    URSUFFIX=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 4 | grep "SLACKBUILD LOCATION:" |sed 's/SLACKBUILD LOCATION: .//g')
    rsync -v $URPREFIX/$URSUFFIX $BUILDPREFIX -r
}


helptext () {
    echo ""
    echo " NAME:"
    echo "	autoslack"
    echo " SYNTAX:"
    echo "	$0 [OPTIONS] -i <packagename> ..."
    echo " OPTIONS:"
    echo "	-h 			This helptext"
    echo "	-v			script version numer"
    echo "	-c			clean the package archive"
    echo "	-j			Just grab sources, don't build anything,"
    echo "				skip interactive checks"
    echo "	-g			Just grab sources, don't build anything,"
    echo "				don't skipt interactive checks"
    echo "	-i <packagename>	install package. "
    echo "	-s <packagename>	find \$packagename"
    echo "	-u			update SLACKBUILDS.TXT"
    echo "	-f			forces a rebuild of package and dependencies"
    echo "	-n			attempt to install without grabbing dependencies"
    echo "	-z			skip md5check for source file. DANGEROUS"
    echo "	-x			force to read package information from"
    echo "				SLACKBUILDS.TXT"
    echo " OTHER:		"
    echo "				the -i option needs to be the last one selected"
}

noopts () {
    echo "You didn't specify any options"
    echo "Please run autoslack -h for assistance"
}
cleanarchive () {
    read -p "Are you sure you want to clean all of your old builds? yes/no " yesno
    if [[ "$yesno" = [yY]* ]]; then 
	rm /usr/share/autoslack/packages/*
	exit 0
    else
	exit 0
    fi
}

prerun () {
    if [[ `ls /usr/share/ | grep autoslack -c` = 0 ]]; then
	mkdir /usr/share/autoslack
	mkdir /usr/share/autoslack/packages
    else
	echo "" > /dev/null
    fi
    #let's make a logging directory
    if [[ `ls /var/log/ | grep autoslack -c` = 0 ]]; then
	mkdir /var/log/autoslack
    else
	echo "" > /dev/null
    fi
    if ((`grep $packagename $SLACKBUILDS -c` >= 1)); then
	echo "available"
    else
	echo "no package called $packagename found, exiting"
	exit 0
    fi
}

update () {
    rsync -v $SLAURL /usr/share/autoslack
}

packagecheck () {
    if ((`ls /var/log/packages | grep $packagename -c` >= 1)); then
	echo "-------------------------------------"
	echo "$packagename or similar appears to be installed already."
	ls /var/log/packages | grep $packagename
	echo "-------------------------------------"
	
	while true; do
	    read -p "do you want to rebuild / reinstall it? [yes/no] " yesno2
	    if [[ "$yesno2" = [yY]* ]]; then
		echo "Ok"
		break
	    elif [[ "$yesno2" = [nN]* ]]; then
		echo "not reinstalling"
		exit 0
	    else
		echo "I didn't catch that"
		continue
	    fi
	done
    else
	echo "" > /dev/null
    fi
}

parsefromfile () {
    source $BUILDPREFIX/$packagename/$packagename.info
#    echo $DOWNLOAD
#    echo $MD5SUM
#    echo $DOWNLOAD_x86_64
#    echo $MD5SUM_x86_64
#    echo $REQUIRES
#    DEPS=$REQUIRES
#    echo $DEPS
#    exit 0
}

depcheck () {
    if [[ $parseslack = 0 ]]; then
	parsefromfile
	DEPS=$REQUIRES
    else
	DEPS=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 8 | grep "REQUIRES" | sed 's/SLACKBUILD REQUIRES: //g' | sed 's/%README%//g' | sed 's/  / /g')
	fi
    if [[ "$DEPS" =~ ^$ ]]; then
	echo "NO DEPENDENCIES, CONTINUE"
    else
	echo "NEED DEPENDENCIES"
	#store deps in an array
	deparr=($DEPS)
	for i in "${deparr[@]}"
	do
	    #haha, we just re-launch the entire process @_@, self-recursion YAY. 
	    #this is going to need to change because obviously the path of the script
	    if [[ "$SKIPBUILD" = 1 ]]; then
		autoslack -j -i $i
	    else
		autoslack -i $i
	    fi
	done
    fi
}


arraychecking() {
    for x in "${urlarr[var]}"
    do 
	filename=$(echo $x | sed 's/.*\///g')
	largefix=$(echo $BUILDPREFIX/$packagename/$filename)
	rm $BUILDPREFIX/$packagename/$filename
	wget $x -P $BUILDPREFIX/$packagename
	if [[ "$MDcheck" != 1 ]]; then
	    for y in "${mdarr[var]}"; do
		#if [[ `md5sum $filename | sed "s/$filename//g"` = "28643857176697dc66786ee898089ca3" ]]; then
		if [[ `md5sum $BUILDPREFIX/$packagename/$filename | awk '{ print $1 }'` = `echo "$y" | sed 's/ //g'` ]]; then
		    echo "yay"
		    echo "------------got------------"
		    md5sum $BUILDPREFIX/$packagename/$filename 
		    echo "----------expected---------"
		    echo "$y"
		    echo "---------------------------"
		    #increment array level to grab the next url and MD5sum
		    var=$((var+1))
		    break
		else
		    echo "------------got------------"
		    md5sum $BUILDPREFIX/$packagename/$filename 
		    echo "----------expected---------"
		    echo "$y"
		    echo "---------------------------"
		    echo $mdarr
		    echo "$package $filename does not pass md5 check. "
		    echo "if you are sure about installing this,"
		    echo "re-run autoslack with the -z option"
		    exit 0
		fi
	    done
	else
	    echo "skipping md5check"
	fi
    done
}

arraychecking2 () {
    echo "ARRAYCHECK"
    #echo ${mdarr@}
    #echo ${urarr@}
    echo "ARRAYS"
    echo $urlarr
    echo $mdarr
    for x in "${urlarr[var]}"
    do
	echo "$x"
    done
    exit 0
}


curlgrab32 (){
    if [[ $parseslack = 0 ]]; then
	parsefromfile
	urls=$DOWNLOAD
	mds=$MD5SUM
    else
	urls=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 4 | grep DOWNLOAD | sed  's/SLACKBUILD DOWNLOAD: //g')
	mds=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 6 | grep "SLACKBUILD MD5SUM" | sed 's/SLACKBUILD MD5SUM: //g')
    fi
    
    urlarr=($urls)
    mdarr=($mds)
    if [[ $urlarr = "UNSUPPORTED" ]];
    then
	while true; do
	    read -p "32bit not supported. Attempt to grab 64bit anyway? [yes/no] " y2n
	    if [[ $y2n = [yY]* ]]; then
		curlgrab64
		break
	    elif [[ $y2n = [nN]* ]]; then
		 echo "not doing anything"
		 exit 0
	    else
		echo "I didn't catch that"
		continue
	    fi
	done
    else
	break
    fi

	
}

curlgrab64 () {
    if [[ $parseslack = 0 ]]; then
	parsefromfile
	urls=$DOWNLOAD_x86_64
	mds=$MD5SUM_x86_64
    else	
	urls=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 5 | grep DOWNLOAD_x86_64 | sed  's/SLACKBUILD DOWNLOAD_x86_64: //g')
	mds=$(grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 7 | grep "SLACKBUILD MD5SUM_x86_64:" | sed 's/SLACKBUILD MD5SUM_x86_64: //g')
    fi
    urlarr=($urls)
    mdarr=($mds)

    if [[ $urlarr = "UNSUPPORTED" ]];
    then
	while true; do
	    read -p "64bit not supported. Attempt to grab 32bit anyway? [yes/no] " y2n
	    if [[ $y2n = [yY]* ]]; then
		curlgrab32
		break
	    elif [[ $y2n = [nN]* ]]; then
		echo "not doing anything"
		exit 0
	    else
		echo "I didn't catch that"
		continue
	    fi
	done
	
    else
	break
    fi

}

archcheck () {
    if [[ `uname -a | grep x86_64 -c` = 1 ]]; then
	#are there seperate sources for amd64?
	if [[ `grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 5 | grep DOWNLOAD_x86_64 | sed  's/SLACKBUILD DOWNLOAD_x86_64: //g'` =~ ^$ ]];
	then
	    curlgrab32
	    arraychecking
	else
	    #if 64bit sources
	    curlgrab64
	    arraychecking
	fi
    else
	#we are not amd64, just grab the normal sources
	curlgrab32
    fi
}



findpackage () {
    grep -iFx "SLACKBUILD NAME: $packagename" $SLACKBUILDS -A 8 | sed 's/SLACKBUILD //g' | grep -v LOCATION | grep -v DOWNLOAD | grep -v MD5SUM
    exit 0
}
installer () {
    #build and install
    #dumb hack to get around some bullshit, because slackbuilds don't enjoy being called remotely. Yay. 
    mypath=$(pwd)
    cd $BUILDPREFIX/$packagename/
    sh *.SlackBuild >> /var/log/autoslack/$logfile
    cd $mypath
    #parse our log file for the installfile
    installpath=$(grep "Slackware package" /var/log/autoslack/$logfile | grep "created" | sed 's/created.//g' | sed 's/Slackware package //g')
    #install package
    installpkg $installpath
    #move the installer file to the slackarchive
    mv $installpath $SLACKRCHIVE
}


while getopts "fnjhxzguvcs:i:r:" option
do 
    case $option in
	h ) helptext
	    exit 0
	    ;;
	v ) echo $scriptversion
	    exit 0
	    ;;
	c ) cleanarchive
	    exit 0
	    ;;
	i ) packagename=${OPTARG}
	    ;;
	u ) update
	    exit 0
	    ;;
	s ) packagename=${OPTARG}
	    findpackage
	    exit 0
	    ;;
	f ) SKIPCHECK="1"
	    ;;
	j ) SKIPCHECK="1"
	    SKIPBUILD="1"
	    ;;
	g ) SKIPBUILD="1"
	    ;;
	n ) SKIPDEP="1"
	    ;;
	z ) MDcheck="1"
	    ;;
	x ) parseslack=1
	    ;;
       	* ) noopts
	    exit 0
	    ;;
    esac
done



#hah, this was most of the script

preprerun
prerun
update
grabslackbuild
parsefromfile
if [[ "$SKIPCHECK" = "1" ]]; then
    echo "" > /dev/null
else
    packagecheck
fi
if [[ "$SKIPDEP" = "1" ]]; then
    echo "" > /dev/null
else
    depcheck
fi
archcheck
if [[ "$SKIPBUILD" =~ "1" ]]; then
    echo "" > /dev/null
else	
    echo "INSTALLING"
    installer
fi
#go back to whence ye came
exit 0

