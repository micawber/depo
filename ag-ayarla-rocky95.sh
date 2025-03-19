#!/bin/bash
echo

nic=`cat /proc/net/dev | grep ens | cut -d":" -f1 | sed 's/^[ \t]*//;s/[ \t]*$//'`
OLD_IP=`ip ad | grep inet | grep $nic | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -d" " -f2 | cut -d"/" -f1`
OLD_HOSTNAME=`hostname -f`
OLD_SHORTNAME=`hostname -s`

NEW_IP="$1"
echo -n "Please enter new IP Address in CIDR format: "
read NEW_IP < /dev/tty

NEW_GW="$1"
echo -n "Please enter new Default Gateway: "
read NEW_GW < /dev/tty

NEW_DNS="$1"
echo -n "Please enter DNS: "
read NEW_DNS < /dev/tty

NEW_DOMAIN="$1"
echo -n "Please enter Domain Name: "
read NEW_DOMAIN < /dev/tty

NEW_HOSTNAME="$1"
echo -n "Please enter hostname (short name): "
read NEW_HOSTNAME < /dev/tty

echo

echo "Changing IP Address to $NEW_IP..."
/usr/bin/nmcli c m $nic ipv4.addresses $NEW_IP

echo "Changing Default Gateway to $NEW_GW..."
/usr/bin/nmcli c m $nic ipv4.gateway $NEW_GW

echo "Changing DNS to $NEW_DNS..."
/usr/bin/nmcli c m $nic ipv4.dns "$NEW_DNS"

echo "Changing Domain Name to $NEW_DOMAIN..."
/usr/bin/nmcli c m $nic ipv4.dns-search $NEW_DOMAIN

echo "Changing hostname $NEW_HOSTNAME..."
/usr/bin/nmcli general hostname $NEW_HOSTNAME.$NEW_DOMAIN

NEW_SHORTNAME=`echo $NEW_HOSTNAME | cut -d"." -f1`

if [ -n "$( grep "$OLD_HOSTNAME" /etc/hosts )" ]; then
 sed -i "s/$OLD_IP/`echo $NEW_IP | cut -d"/" -f1`/g" /etc/hosts
 sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
 sed -i "s/$OLD_SHORTNAME/$NEW_SHORTNAME/g" /etc/hosts
 else
 echo -e "$NEW_IP\t$NEW_HOSTNAME\t$NEW_SHORTNAME" >> /etc/hosts
fi

echo "Done."