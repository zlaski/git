#!/bin/bash

# Based on https://github.com/alexsarmiento/gitportable-pacman/blob/master/install-pacman-git-bash.sh

# Script to install pacman package management
# in Git for Windows Portable
# To be run from a git-bash session.

ESC=

RED=$ESC[91m
GREEN=$ESC[92m
YELLOW=$ESC[93m
BLUE=$ESC[94m
MAGENTA=$ESC[95m
CYAN=$ESC[96m
WHITE=$ESC[97m
DEFAULT=$ESC[0m

SCRIPT=$(basename $0 .sh)
cd $TMP

if [[ "$MSYSTEM" == "MINGW32" ]]; then
  BT=32
elif [[ "$MSYSTEM" == "MINGW64" ]]; then
  BT=64
else
  echo "${RED}${SCRIPT}: Only MinGW32 or MinGW64 supported.${DEFAULT}"
  exit 1
fi

GITURL="https://github.com/git-for-windows/git-sdk-$BT.git"
RAWURL="https://github.com/git-for-windows/git-sdk-$BT/raw"

if test ! -d git-sdk-$BT; then
    rm -rf git-sdk-$BT
    # Clone tiny blobless shallow repo
    git clone \
        --depth 50 \
        --filter=blob:none \
        --no-checkout \
        $GITURL
fi

cd  git-sdk-$BT
git pull

### Pre install minimal pacman bootstrap
d="var/lib/pacman/local"
mkdir -p "/$d"
pkgs=('pacman-6' 'pacman-mirrors-' 'msys2-keyring-')
for j in ${pkgs[@]} ; do
	pacvers=$(basename $( git show main:$d|grep "$j" ))
	echo $pacvers
	shfiles=$(curl -sSL $RAWURL/main/$d/$pacvers/files )	
	for f in $shfiles
	do 
	 if [[ $f = *"/"* ]] && [[ $f != *"/man/"* ]] && [[ $f != *"locale/"* ]] && [[ $f != *\/ ]]
	  then
	  		if [ ! -f "/$f" ]
				then
					mkdir -p /$(dirname "$f" ) 
					curl -sSL $RAWURL/main/$f -o /$f &
					[ $( jobs | wc -l ) -ge $( nproc ) ] && wait
			fi
	 fi  
	done
	wait
done
wait	

mkdir -p /var/lib/pacman
pacman-key --init
pacman-key --populate msys2
curl -L https://raw.githubusercontent.com/git-for-windows/build-extra/HEAD/git-for-windows-keyring/git-for-windows.gpg |\
pacman-key --add - &&
pacman-key --lsign-key E8325679DFFF09668AD8D7B67115A57376871B1C &&
pacman-key --lsign-key 3B6D86A1BA7701CD0F23AED888138B9E1A9F3986
pacman -Sy

################
#Restore Pacman metadata
d="var/lib/pacman/local"
for j in ${pkgs[@]} ; do
	pacvers=$(basename $( git show main:$d|grep "$j" ))
	for f in desc install files mtree; do
		git show main:$d/$pacvers/$f > /dev/null 2>%1
		if [ $? -eq 0 ]; then
		mkdir -p /$d/$pacvers
		[ ! -f "/$d/$pacvers/$f" ] && curl -sSL "$RAWURL/main/$d/$pacvers/$f" -o /$d/$pacvers/$f
		echo "$d/$pacvers/$f"
		fi
	done
done
#################
commits=$(git log --pretty=%h)
######## Packages metadata
spdup ()
{
	package=$1
	version=$2
	for cs in $commits ; do
	    d=var/lib/pacman/local/$package-$version
		[ ! -d /$d ] && mkdir -p /$d
		git show $cs:$d >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
			for f in desc files install mtree; do 
				git show $cs:$d/$f > /dev/null 2>&1
				if [ $? -eq 0 ]
				then
				 [ ! -f "/$d/$f" ] && curl -sSL "$RAWURL/$cs/$d/$f" -o /$d/$f 
				fi
			done
			echo -e "$cs\t$package $version"
			break
		fi
	done 
}


cat /etc/package-versions.txt |while read package version
do
	spdup $package $version & 
	[ $( jobs | wc -l ) -ge $( nproc ) ] && wait

done
wait 

### Wrap up

pacman -Sy filesystem bash-completion --noconfirm

# Sync new repositories. This will also allow downgrades as well. This will also kill the MSYS2
echo
echo
echo "###################################################################"
echo "#                                                                 #"
echo "#                                                                 #"
echo "#                   W   A   R   N   I   N   G                     #"
echo "#                                                                 #"
echo "#    Select Y to re-install MSYS2. After restart, manually run    #"
echo "#          'pacman -Suu' to update rest of applications.          #"
echo "#                                                                 #"
echo "#                                                                 #"
echo "###################################################################"
echo
echo
read -rs -p $"Press escape or arrow key to continue or wait 5 seconds..." -t 5 -d $'\e';echo;
pacman -Syyuu
