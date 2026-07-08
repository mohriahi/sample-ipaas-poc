ARG WSO2AM_VERSION=4.7.0
FROM wso2/wso2am:${WSO2AM_VERSION}

ARG WSO2AM_VERSION=4.7.0
ARG MYSQL_CONNECTOR_VERSION=8.4.0

# MySQL Connector/J: GPL-licensed, so not bundled in the base WSO2 image.
USER root
RUN curl -sL -o "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/repository/components/lib/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
      "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
    && chown wso2carbon:wso2 "/home/wso2carbon/wso2am-${WSO2AM_VERSION}/repository/components/lib/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar"
USER wso2carbon
