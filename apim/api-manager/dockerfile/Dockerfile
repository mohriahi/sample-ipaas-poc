ARG WSO2AM_VERSION=4.7.0
FROM wso2/wso2am:${WSO2AM_VERSION}

ARG WSO2AM_VERSION=4.7.0
ARG MYSQL_CONNECTOR_VERSION=8.4.0
ARG JMX_EXPORTER_VERSION=1.6.0

# MySQL Connector/J: GPL-licensed, so not bundled in the base WSO2 image.
USER root
RUN curl -sL -o "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/repository/components/lib/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
      "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
    && chown wso2carbon:wso2 "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/repository/components/lib/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar"

# Prometheus JMX exporter: exposes API Manager metrics to Prometheus
# (API Manager has no built-in Prometheus support).
# It is enabled through its own variable (JMX_EXPORTER_OPTS) rather than
# JAVA_OPTS: a diagnostics tool started alongside the server also reads
# JAVA_OPTS, would take the metrics port first, and the server would not start.
# The build fails if the startup script could not be patched.
RUN mkdir -p /home/wso2carbon/jmx-exporter \
    && curl -sL -o "/home/wso2carbon/jmx-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" \
      "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar" \
    && chown -R wso2carbon:wso2 /home/wso2carbon/jmx-exporter \
    && sed -i 's|^    \$JAVA_OPTS \\$|    $JAVA_OPTS $JMX_EXPORTER_OPTS \\|' "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/bin/api-manager.sh" \
    && grep -q 'JAVA_OPTS \$JMX_EXPORTER_OPTS' "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/bin/api-manager.sh"
COPY --chown=wso2carbon:wso2 jmx-exporter/config.yml /home/wso2carbon/jmx-exporter/config.yml
USER wso2carbon
