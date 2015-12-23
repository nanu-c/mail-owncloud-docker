#!/bin/bash

if [ -f /firstrun ]
  then
    # remote syslog server to docker host
    SYSLOG=`netstat -rn|grep ^0.0.0.0|awk '{print $2}'`
    echo "*.*	@$SYSLOG" > /etc/rsyslog.d/50-default.conf

    # Start syslog server to see something
    /etc/init.d/rsyslog start

    echo "Running for first time..need to configure..."

    source /mail-setup.sh

    # Stopping ALL services so data can be moved if needed
    /etc/init.d/postfix stop
    /etc/init.d/spamassassin stop
    /etc/init.d/rsyslog stop

    # Moving data /data or not?
    if [ ! -d /data ]
      then
        echo "No /data found so assuming you've set up your own persistent volumes (-v </<dir> or --volumes-from <data container> ) or don't want it "
      else
        BASE="/data"

        if `ls -A $BASE`
         then
           echo "Clean install apparently"

	         # Put certs on one place
           mkdir $BASE/ssl $BASE/ssl/certs $BASE/ssl/keys

           # Move maildir
           mv /var/vmail $BASE/vmail
           ln -s $BASE/vmail /var/vmail

           # Move certs and keys
           mv /etc/ssl/certs/ssl-cert-snakeoil.pem $BASE/ssl/certs/ssl-$HOSTNAME.pem
           ln -s $BASE/ssl/certs/ssl-$HOSTNAME.pem /etc/ssl/certs/ssl-cert-snakeoil.pem
           mv /etc/ssl/private/ssl-cert-snakeoil.key $BASE/ssl/keys/ssl-$HOSTNAME.key
           ln -s $BASE/ssl/keys/ssl-$HOSTNAME.key /etc/ssl/private/ssl-cert-snakeoil.key
           mv /etc/dovecot/dovecot.pem $BASE/ssl/certs/
           ln -s $BASE/ssl/certs/dovecot.pem /etc/dovecot/dovecot.pem
           mv /etc/dovecot/private/dovecot.pem $BASE/ssl/keys/
           ln -s $BASE/ssl/keys/dovecot.pem /etc/dovecot/private/dovecot.pem

         else
           rm -rf /var/vmail
           ln -s $BASE/vmail /var/vmail
           # certs
           rm /etc/ssl/certs/ssl-cert-snakeoil.pem
           ln -s $BASE/ssl/certs/ssl-$HOSTNAME.pem /etc/ssl/certs/ssl-cert-snakeoil.pem
           rm /etc/ssl/private/ssl-cert-snakeoil.key
           ln -s $BASE/ssl/keys/ssl-$HOSTNAME.key /etc/ssl/private/ssl-cert-snakeoil.key
           rm /etc/dovecot/dovecot.pem
           ln -s $BASE/ssl/certs/dovecot.pem /etc/dovecot/dovecot.pem
           rm /etc/dovecot/private/dovecot.pem
           ln -s $BASE/ssl/keys/dovecot.pem /etc/dovecot/private/dovecot.pem

        fi
    fi

    # clean up
    rm /*-setup.sh
    rm /firstrun

fi

# Sometimes with un unclean exit the rsyslog pid doesn't get removed and refuses to start
if [ -f /var/run/rsyslogd.pid ]
  then rm /var/run/rsyslogd.pid
fi


# Start supervisor to start the services
/usr/bin/supervisord
