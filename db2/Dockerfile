# IBM Db2 Community Edition with the NovaBank schema and sample data baked in.
# The first container start creates the instance and NOVABANK database (3 to 6 minutes),
# then /var/custom/init-novabank.sh loads db2/schema/*.sql exactly once per volume.
ARG DB2_IMAGE=icr.io/db2_community/db2:11.5.9.0
FROM ${DB2_IMAGE}
COPY docker/init-novabank.sh /var/custom/init-novabank.sh
COPY schema/ /novabank-sql/
RUN chmod 755 /var/custom/init-novabank.sh && chmod -R a+rX /novabank-sql
