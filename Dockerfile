FROM tomcat:9-jdk17

# Clean default apps
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy WAR file from artifact
COPY Amazon-Web/target/Amazon.war /usr/local/tomcat/webapps/Amazon.war

EXPOSE 8080