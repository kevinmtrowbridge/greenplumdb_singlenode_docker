# Greenplum Database (GPDB) "Single Node" Dockerized for testing purposes only.

# NOTES:
#
# Most useful GPDB docs I found:
# http://gpdb.docs.pivotal.io/gs/43/pdf/GPDB43xGettingStarted.pdf
#
# Loosely based on "Dockerfile for Greenplum SNE 4.2.6.1": https://gist.github.com/teraflopx/a0af37a880164da87198#comments
#
# Useful Docker commands:
# docker build -t kevinmtrowbridge/greenplumdb_singlenode .
# docker run -i -p 5432:5432 -t greenplumdb_singlenode
# docker ps ... docker exec -it <running container name> bash
#
# Test that it's working by accessing it via PSQL:
# psql -h `docker-machine ip default` -p 5432 -U gpadmin template1
# PASSWORD IS: secret (set by gpinitsystem below)
#
# To view the logs:
# docker exec -it <running container name> bash
# tail -f /data/gpmaster/gpsne-1/pg_log/*
#
# TODO:
# * send all logs to STDOUT so that we can see all logs without needing to enter the container
#

FROM centos:6.6
MAINTAINER kevinmtrowbridge@gmail.com

RUN yum update -y
RUN yum install -y ed which tar sed openssh-server openssh-clients
RUN yum clean all


# CENTOS MODIFICATIONS

# It's dubious how well the sysctl.conf settings are working ... there's also the option of tuning the kernel
# at runtime (using docker run -w) ...
COPY centos/etc_sysctl.conf /tmp/sysctl.conf
RUN cat /tmp/sysctl.conf >> /etc/sysctl.conf

COPY centos/etc_security_limits.conf /tmp/limits.conf
RUN cat /tmp/limits.conf >> /etc/security/limits.conf
RUN rm /etc/security/limits.d/90-nproc.conf


# CUE GPADMIN USER

RUN groupadd -g 8000 gpadmin
RUN useradd -m -s /bin/bash -d /home/gpadmin -g gpadmin -u 8000 gpadmin

# NECESSARY: key exchange with ourselves - needed by single-node greenplum and hadoop
RUN service sshd start && ssh-keygen -t rsa -q -f /root/.ssh/id_rsa -P "" &&\
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && ssh-keyscan -t rsa localhost >> /root/.ssh/known_hosts &&\
  ssh-keyscan -t rsa localhost >> /root/.ssh/known_hosts

RUN mkdir -p /data/gpmaster /data/gpdata1 /data/gpdata2
RUN chown -R gpadmin:gpadmin /data

# COPY GPDB FILES INTO PLACE
COPY greenplum-db-appliance-4.3.7.1-build-1-RHEL5-x86_64.bin greenplum-db-appliance-4.3.7.1-build-1-RHEL5-x86_64.bin
RUN echo "localhost" > hostfile
RUN service sshd start && /bin/bash greenplum-db-appliance-4.3.7.1-build-1-RHEL5-x86_64.bin &&\
  rm hostfile greenplum-db-appliance-4.3.7.1-build-1-RHEL5-x86_64.bin

ENV GPHOME /usr/local/greenplum-db

WORKDIR /home/gpadmin
COPY bash/.gpadmin_bash_profile .bash_profile

COPY gpdb/hostlist_singlenode hostlist_singlenode
COPY gpdb/gpinitsystem_singlenode gpinitsystem_singlenode

RUN chown -R gpadmin:gpadmin /home/gpadmin

RUN service sshd start && su gpadmin -l -c "gpssh-exkeys -h localhost"

# INITIALIZE GPDB SYSTEM
# HACK: note, capture of unique docker hostname -- at this point, the hostname gets embedded into the installation ... :(
RUN service sshd start &&\
 hostname > /docker_hostname_at_moment_of_gpinitsystem &&\
 su gpadmin -l -c "gpinitsystem -a -D -c /home/gpadmin/gpinitsystem_singlenode --su_password=secret;"; exit 0;


# HACK: docker_transient_hostname_workaround, explanation:
#
# When gpinitsystem runs, it embeds the hostname (at that moment) into the installation.  Since Docker generates a new
# random hostname each time it runs, the hostname that is embedded, will never work again.  When you run `gpstart`, if
# the embedded hostname is not a valid DNS name, it will fail with this error:
#
# gpadmin-[ERROR]:-gpstart failed.  exiting...
# <snip>
#    addrinfo = socket.getaddrinfo(hostToPing, None)
# gaierror: [Errno -2] Name or service not known
#
# (You can reproduce this by removing the `docker_transient_hostname_workaround` bit from the CMD at the bottom.)
#
# So what we do here is to capture the random hostname at the moment that gpinitsystem is run, and later we can append
# it to /etc/hosts when we run `gpstart` -- this seems to keep it happy.
#
COPY bash/docker_transient_hostname_workaround.sh docker_transient_hostname_workaround.sh
RUN chmod +x docker_transient_hostname_workaround.sh


# WIDE OPEN GPDB ACCESS PERMISSIONS
COPY gpdb/allow_all_password_incoming_pg_hba.conf /data/gpmaster/gpsne-1/pg_hba.conf
COPY gpdb/postgresql.conf /data/gpmaster/gpsne-1/postgresql.conf

EXPOSE 5432

# THIS DOCKER IMAGE WILL BE USED FOR TESTING SO WE DON'T CARE ABOUT THE DATA, AT ALL
# VOLUME ["/data"]


CMD ./docker_transient_hostname_workaround.sh && service sshd start &&\
  su gpadmin -l -c "gpstart -a --verbose" && sleep 2678400 # HACK: it's difficult to get Docker to attach to the GPDB process(es) ... so, instead attach to process "sleep for 1 month"