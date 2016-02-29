# NOTE -- Docker issue: unable to edit /etc/hosts ... workaround is to set it within each RUN statement,
# where the added domain names must be in effect.
# http://serverfault.com/questions/679738/cannot-write-to-etc-hosts-file-from-dockerfile-with-run

if [ -e /docker_hostname_at_moment_of_gpinitsystem ]
then
  mapfile < /docker_hostname_at_moment_of_gpinitsystem
  echo "127.0.0.1 ${MAPFILE[@]}" | tee -a /etc/hosts
fi