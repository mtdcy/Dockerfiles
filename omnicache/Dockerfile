# syntax=docker/dockerfile:1

FROM mtdcy/nginx:latest

LABEL maintainer="mtdcy.chen@gmail.com"

# install omnicache
ADD app /app/omnicache
RUN ln -svf omnicache/omnicache.nginx /app/

# add entrypoint
ADD entrypoint.sh /sbin/entrypoint.sh
RUN chmod 0755 /sbin/entrypoint.sh
ENTRYPOINT ["/sbin/entrypoint.sh"]

# exposed ports 
# 80/443:       default ports
# 81-88:        debugging ports
EXPOSE 80-88 443

VOLUME ["/data"]
