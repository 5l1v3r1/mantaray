#!/bin/sh -
#===============================================================================
# vim: softtabstop=4 shiftwidth=4 expandtab fenc=utf-8 spell spelllang=en cc=81
#===============================================================================


#--- FUNCTION ----------------------------------------------------------------
# NAME: __function_defined
# DESCRIPTION: Checks if a function is defined within this scripts scope
# PARAMETERS: function name
# RETURNS: 0 or 1 as in defined or not defined
#-------------------------------------------------------------------------------
__function_defined() {
    FUNC_NAME=$1
    if [ "$(command -v $FUNC_NAME)x" != "x" ]; then
        echoinfo "Found function $FUNC_NAME"
        return 0
    fi
    
    echodebug "$FUNC_NAME not found...."
    return 1
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: __strip_duplicates
# DESCRIPTION: Strip duplicate strings
#-------------------------------------------------------------------------------
__strip_duplicates() {
    echo $@ | tr -s '[:space:]' '\n' | awk '!x[$0]++'
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echoerr
# DESCRIPTION: Echo errors to stderr.
#-------------------------------------------------------------------------------
echoerror() {
    printf "${RC} * ERROR${EC}: $@\n" 1>&2;
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echoinfo
# DESCRIPTION: Echo information to stdout.
#-------------------------------------------------------------------------------
echoinfo() {
    printf "${GC} * INFO${EC}: %s\n" "$@";
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echowarn
# DESCRIPTION: Echo warning informations to stdout.
#-------------------------------------------------------------------------------
echowarn() {
    printf "${YC} * WARN${EC}: %s\n" "$@";
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echodebug
# DESCRIPTION: Echo debug information to stdout.
#-------------------------------------------------------------------------------
echodebug() {
    if [ $_ECHO_DEBUG -eq $BS_TRUE ]; then
        printf "${BC} * DEBUG${EC}: %s\n" "$@";
    fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __apt_get_install_noinput
#   DESCRIPTION:  (DRY) apt-get install with noinput options
#-------------------------------------------------------------------------------
__apt_get_install_noinput() {
    apt-get install -y -o DPkg::Options::=--force-confold $@; return $?
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __apt_get_upgrade_noinput
#   DESCRIPTION:  (DRY) apt-get upgrade with noinput options
#-------------------------------------------------------------------------------
__apt_get_upgrade_noinput() {
    apt-get upgrade -y -o DPkg::Options::=--force-confold $@; return $?
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __pip_install_noinput
#   DESCRIPTION:  (DRY)
#-------------------------------------------------------------------------------
__pip_install_noinput() {
    pip install --upgrade $@; return $?
}

__ScriptVersion=20140505	

__enable_universe_repository() {
    if [ "x$(grep -R universe /etc/apt/sources.list /etc/apt/sources.list.d/ | grep -v '#')" != "x" ]; then
        # The universe repository is already enabled
        return 0
    fi

    echodebug "Enabling the universe repository"

    # Ubuntu versions higher than 12.04 do not live in the old repositories
    if [ $DISTRO_MAJOR_VERSION -gt 12 ] || ([ $DISTRO_MAJOR_VERSION -eq 12 ] && [ $DISTRO_MINOR_VERSION -gt 04 ]); then
        add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1
    elif [ $DISTRO_MAJOR_VERSION -lt 11 ] && [ $DISTRO_MINOR_VERSION -lt 10 ]; then
        # Below Ubuntu 11.10, the -y flag to add-apt-repository is not supported
        add-apt-repository "deb http://old-releases.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1
    fi

    add-apt-repository -y "deb http://old-releases.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1

    return 0
}

__check_unparsed_options() {
    shellopts="$1"
    # grep alternative for SunOS
    if [ -f /usr/xpg4/bin/grep ]; then
        grep='/usr/xpg4/bin/grep'
    else
        grep='grep'
    fi
    unparsed_options=$( echo "$shellopts" | ${grep} -E '(^|[[:space:]])[-]+[[:alnum:]]' )
    if [ "x$unparsed_options" != "x" ]; then
        usage
        echo
        echoerror "options are only allowed before install arguments"
        echo
        exit 1
    fi
}

configure_cpan() {
    (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan > /dev/null
}

usage() {
    echo "usage"
    echo
    echo "h - print this message"
    echo "s - install the skin"
    echo "i - install the tools"
    echo "k - install kibana"
    echo "c - configure only"
    echo "y - yes to all"
    exit 1
}

install_ubuntu_deps() {
    apt-get update

    __apt_get_install_noinput python-software-properties || return 1

    __enable_universe_repository || return 1

    add-apt-repository -y ppa:sift/$@ || return 1

    add-apt-repository -y ppa:mantaray/$@ || return 1

    apt-get update

    __apt_get_upgrade_noinput || return 1

    return 0
}

install_ubuntu() {
    packages="mantaray binplist bulk-extractor dos2unix libevt libevt-dev libevt-tools libevt-python libevt libevtx-dev libevtx-tools libevtx-python libewf libewf-dev libewf-tools libewf-python libfvde libfvde-dev libfvde-tools liblightgrep libolecf libolecf-dev libolecf-tools libolecf-python libolecf-tools libplist++1 libplist-dev libplist1 libregf libregf-python libregf-tools libregf-dev libvshadow libvshadow-tools libvshadow-dev libvshadow-python log2timeline-perl mantaray python-plaso pytsk3 regripper sift libtsk libtsk-dev sleuthkit windows-perl python-pip python3 git"

    if [ "$@" = "dev" ]; then
        packages="$packages"
    elif [ "$@" = "stable" ]; then
        packages="$packages"
    fi

    __apt_get_install_noinput $packages || return 1

    return 0
}

install_pip_packages() {
    pip_packages="rekall docopt python-evtx python-registry"

    if [ "$@" = "dev" ]; then
        pip_packages="$pip_packages"
    elif [ "$@" = "stable" ]; then
        pip_packages="$pip_packages"
    fi

    __pip_install_noinput $pip_packages || return 1

    return 0
}

install_perl_modules() {
	# Required by macl.pl script
	perl -MCPAN -e "install Net::Wigle" > /dev/null
}

configure_ubuntu() {
	if [ ! -d /cases ]; then
		mkdir -p /cases
		chown $SUDO_USER:$SUDO_USER /cases
		chmod 775 /cases
		chmod g+s /cases
	fi

	for dir in usb vss shadow windows_mount e01 aff ewf bde iscsi
	do
		if [ ! -d /mnt/$dir ]; then
			mkdir -p /mnt/$dir
		fi
	done

	for NUM in 1 2 3 4 5
	do
		if [ ! -d /mnt/windows_mount$NUM ]; then
			mkdir -p /mnt/windows_mount$NUM
		fi
		if [ ! -d /mnt/ewf$NUM ]; then
			mkdir -p /mnt/ewf$NUM
		fi
	done
 
	for NUM in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
	do
		if [ ! -d /mnt/shadow/vss$NUM ]; then
			mkdir -p /mnt/shadow/vss$NUM
		fi
		if [ ! -d /mnt/shadow_mount/vss$NUM ]; then
			mkdir -p /mnt/shadow_mount/vss$NUM
		fi
	done
	
	if [ ! -L /usr/bin/vol.py ]; then
		ln -s /usr/bin/vol /usr/bin/vol.py
	fi
	if [ ! -L /usr/bin/log2timeline ]; then
		ln -s /usr/bin/log2timeline_legacy /usr/bin/log2timeline
	fi
	if [ ! -L /usr/bin/kedit ]; then
		ln -s /usr/bin/gedit /usr/bin/kedit
	fi
	if [ ! -L /usr/bin/mount_ewf.py ] && [ ! -e /usr/bin/mount_ewf.py ]; then
		ln -s /usr/bin/ewfmount /usr/bin/mount_ewf.py
	fi
}

download_install_kibana() {
        
        echo "##############################"
        echo "##############################"
        echo
        echo
        echo "Installing Kibana and Elasticsearch"
        echo

        wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.13.deb
        dpkg -i elasticsearch-0.90.13.deb
        sudo rm elasticsearch-0.90.13.deb

        git clone https://github.com/rhec/pyelasticsearch.git

        python pyelasticsearch/setup.py build 
        sudo python pyelasticsearch/setup.py install
        sudo rm -r pyelasticsearch

        wget https://download.elasticsearch.org/kibana/kibana/kibana-3.0.0.tar.gz
        tar zxvf kibana-3.0.0.tar.gz

        sudo apt-get install nginx -y

        sudo mv kibana-3.0.0 /usr/share/kibana3/

        sudo mv /usr/share/kibana3/config.js /usr/share/kibana3/config.js.backup

        wget https://github.com/mantarayforensics/mantaray/raw/kibana/usr/share/etc/kibana/config.js
        wget https://github.com/mantarayforensics/mantaray/raw/kibana/usr/share/etc/kibana/kibana
        wget https://github.com/mantarayforensics/mantaray/raw/kibana/usr/share/etc/kibana/plaso.json

        sudo mv config.js /usr/share/kibana3/
        sudo mv kibana /etc/nginx/sites-available/kibana
        sudo rm /etc/nginx/sites-enabled/default
        sudo ln -s /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/

        sudo mv /usr/share/kibana3/app/dashboards/default.json /usr/share/kibana3/app/dashboards/inital_default.json
        sudo mv plaso.json /usr/share/kibana3/app/dashboards/default.json 

        sudo service nginx restart

        echo
        echo
        echo "Installed Kibana and Elasticsearch"
        echo
        echo
        echo "##############################"
        echo "##############################"



}

configure_ubuntu_skin() {
	if [ ! -d /home/$SUDO_USER/.config/autostart ]; then
		sudo -u $SUDO_USER mkdir -p /home/$SUDO_USER/.config/autostart
	fi

	sudo -u $SUDO_USER gsettings set org.gnome.desktop.background picture-uri file:///usr/share/mantaray/images/Mantaray_Logo_Template_Full_Screen.gif
	sudo -u $SUDO_USER dconf write /desktop/unity/launcher/favorites "['nautilus.desktop', 'gnome-terminal.desktop', 'firefox.desktop', 'gnome-screenshot.desktop', 'gcalctool.desktop', 'bless.desktop', 'dff.desktop', 'autopsy.desktop', 'wireshark.desktop', 'MantaRay.desktop']"

	if [ ! -L /home/$SUDO_USER/Desktop/cases ]; then
		sudo -u $SUDO_USER ln -s /cases /home/$SUDO_USER/Desktop/cases
	fi
  
	if [ ! -L /home/$SUDO_USER/Desktop/mount_points ]; then
		sudo -u $SUDO_USER ln -s /mnt /home/$SUDO_USER/Desktop/mount_points
	fi

	# Clean up broken symlinks
	find -L /home/$SUDO_USER/Desktop -type l -delete

	for file in /usr/share/sift/resources/*.pdf
	do
		base=`basename $file`
		if [ ! -L /home/$SUDO_USER/Desktop/$base ]; then
			sudo -u $SUDO_USER ln -s $file /home/$SUDO_USER/Desktop/$base
		fi
	done
	
	if [ ! -L /home/$SUDO_USER/.config/autostart ]; then
		sudo -u $SUDO_USER cp /usr/share/sift/other/gnome-terminal.desktop /home/$SUDO_USER/.config/autostart
	fi
    
	if [ ! -e /usr/share/unity-greeter/logo.png.ubuntu ]; then
		sudo cp /usr/share/unity-greeter/logo.png /usr/share/unity-greeter/logo.png.ubuntu
		sudo cp /usr/share/sift/images/login_logo.png /usr/share/unity-greeter/logo.png
	fi

	gsettings set com.canonical.unity-greeter background file:///usr/share/mantaray/images/Mantaray_Logo_Template_Full_Screen.gif

	# Checkout code from sift-files and put these files into place
	CDIR=$(pwd)
	git clone https://github.com/sans-dfir/sift-files /tmp/sift-files
	cd /tmp/sift-files
	bash install.sh
	cd $CDIR
	rm -r -f /tmp/sift-files

	# Make sure we replace the SIFT_USER template with our actual
	# user so there is write permissions to samba.
	sed -i "s/SIFT_USER/$SUDO_USER/g" /etc/samba/smb.conf

	# Restart samba services 
	service smbd restart
	service nmbd restart

	# Disable services
	update-rc.d tor disable

	# Make sure to remove all ^M from regripper plugins
	# Not sure why they are there in the first place ...
	dos2unix -ascii /usr/share/regripper/*

	OLD_HOSTNAME=$(hostname)
	sed -i "s/$OLD_HOSTNAME/mantarayforensics/g" /etc/hosts
	echo "mantarayforensics" > /etc/hostname
	hostname mantarayforensics

	if ! grep -i "set -o noclobber" $HOME/.bashrc > /dev/null 2>&1
	then
		echo "set -o noclobber" >> $HOME/.bashrc
	fi

	if ! grep -i "alias mountwin" $HOME/.bash_aliases > /dev/null 2>&1
	then
		echo "alias mountwin='mount -o ro,loop,show_sys_files,streams_interface=windows'" >> $HOME/.bash_aliases
	fi
}


complete_message() {
    echo
    echo "Installation Completed!"
    echo 
    echo "Formal documentation is in progress."
    echo
    echo "http://mantaray.readthedocs.org"
    echo
}

complete_message_kibana() {
    echo
    echo "Please restart before using kibana & elasticsearch features"
    echo
    echo "To access kibana interface, load http://localhost in the webbrowser"
    echo
}

complete_message_skin() {
    echo "The hostname was changed, you should relogin or reboot for it to take full effect."
    echo
    echo "sudo reboot"
    echo
}

CONFIGURE_ONLY=0
SKIN=0
INSTALL=1
YESTOALL=0
KIBANA=0

OS=$(lsb_release -si)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VER=$(lsb_release -sr)


if [ $OS != "Ubuntu" ]; then
    echo "MantaRay is only installable on Ubuntu operating systems at this time."
    exit 1
fi

if [ $ARCH != "64" ]; then
    echo "MantaRay is only installable on a 64 bit architecture at this time."
    exit 2
fi

if [ $VER != "12.04" ]; then
    echo "MantaRay is only installable on Ubuntu 12.04 at this time."
    exit 3
fi

if [ `whoami` != "root" ]; then
    echo "MantaRay Bootstrap must be run as root!"
    exit 3
fi

if [ "$SUDO_USER" = "" ]; then
    echo "The SUDO_USER variable doesn't seem to be set"
    exit 4
fi


while getopts ":hvcskiy" opt
do
case "${opt}" in
    h ) usage; exit 1;;
    v ) echo "$0 -- Version $__ScriptVersion"; exit 0 ;;
    s ) SKIN=1 ;;
    i ) INSTALL=1 ;;
    k ) KIBANA=1 ;;
    c ) CONFIGURE_ONLY=1; INSTALL=0; SKIN=0; KIBANA=0; ;;
    y ) YESTOALL=1 ;;
    \?) echo
        echoerror "Option does not exist: $OPTARG"
        usage
        exit 1
        ;;
esac
done

shift $(($OPTIND-1))

if [ "$#" -eq 0 ]; then
    ITYPE="stable"
else
    __check_unparsed_options "$*"
    ITYPE=$1
    shift
fi

# Check installation type
if [ "$(echo $ITYPE | egrep '(dev|stable)')x" = "x" ]; then
    echoerror "Installation type \"$ITYPE\" is not known..."
    exit 1
fi


echo "Welcome to the MantaRay Bootstrap"
echo "This script will now proceed to configure your system."

if [ "$YESTOALL" -eq 1 ]; then
    echo "You supplied the -y option, this script will not exit for any reason"
fi

if [ "$SKIN" -eq 1 ] && [ "$YESTOALL" -eq 0 ]; then
    echo
    echo "You have chosen to apply the MantaRay skin to your ubuntu system."
    echo 
    echo "You did not choose to say YES to all, so we are going to exit."
    echo
    echo "Your current user is: $SUDO_USER"
    echo
    echo "Re-run this command with the -y option"
    echo
    exit 10
fi

if [ "$INSTALL" -eq 1 ] && [ "$CONFIGURE_ONLY" -eq 0 ]; then
    install_ubuntu_deps $ITYPE
    install_ubuntu $ITYPE
    install_pip_packages $ITYPE
    configure_cpan
    install_perl_modules
fi

configure_ubuntu

if [ "$KIBANA" -eq 1 ]; then
    download_install_kibana
    complete_message_kibana
fi

if [ "$SKIN" -eq 1 ]; then
    configure_ubuntu_skin
fi

complete_message

if [ "$SKIN" -eq 1 ]; then
    complete_message_skin
fi


