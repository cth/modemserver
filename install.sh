#/bin/sh

INSTDIR=/opt/modemserver

if [ ! `whoami` == "root" ]; then
	echo "Must be root"
	exit
fi

if [ ! -d $INSTDIR ]; then
	mkdir $INSTDIR	
fi

# copy files
echo "Installing files to $INSTDIR" 
cp * $INSTDIR

echo "Installing init script (/etc/init.d/modemserver)"
cp modemserver.init /etc/init.d/modemserver
chmod +x /etc/init.d/modemserver

if [ -f /etc/modemserver.conf ]; then
	echo "Skipping installation of configuraiton file"
else
	echo "Installing sample configuration file"
	cp -f config.xml /etc/modemserver.conf
	echo "Make sure to edit /etc/modemserver.conf before starting the modemserver"
fi

echo "Done."
