[[_TOC_]]

# nexus3-tls
This Dockerfile provides a **Nexus 3.37.3** Repository Manager with TLS only support.

The enabled TLS Versions are the following:
* TLSv1.2
* TLSv1.3

This can be changed in the Dockerfile.

Nevertheless, you can enable plain HTTP Support by adding `${jetty.etc}\/jetty-http.xml` to the comma seperated list of the `-e '/nexus-args=...'` Expression in the "*configure nexus and enable TLS*" section of the Dockerfile.

## Requisite
- tls **private key** named *cert.key.pem*  
- tls **public** certificate, or a certificate chain, named *cert.pem*

Just provide this in the directory wich is passed to the docker damon at build time.

To obtain a tls certificate you can use [Certbot](https://certbot.eff.org/#debianstretch-other) or generate a certificate locally for testing or development:
```bash
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout cert.key.pem -out cert.pem
```

Keep in mind that you have to rebuild the image with the renewed certificate every 90 days, when obtaining the certificate with certbot! But no data will be lost if you create a volume and map it to the nexus-data (sonatype-work) directory as shown bellow or when you use `docker-compose`.

## Build the image
To build the image:
```bash
docker build --rm=true --tag=avensio/nexus3-tls .
or
docker build --rm=true --tag=avensio/nexus3-tls --build-arg TLS_STOREPASS=changeit123123
```
You can pass the following arguments to the build:  
- **TLS_STOREPASS**       (default: changeit)
- **NEXUS_VERSION**       (default: 3.37.3-02 (see [latest version](https://help.sonatype.com/repomanager3/product-information/download)))
- **NEXUS_DOWNLOAD_URL**  (default: https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz)
- **NEXUS_CONTEXT_PATH**  (default: '/')
- **Xms**                 (default: 2048m)
- **Xmx**                 (default: 2048m)
- **MDMS** (MaximumDirectoryMemorySize) (default: 2g)

The default **HTTP** Port, when enabled, is **8081** and the default **HTTPS** Port **8443**. This values can be changed in the `Dockerfile`.  

When a `NEXUS_DOWNLOAD_URL` is provided, don't forget to also provide the appropriate `NEXUS_VERSION` (Otherwise you have a correct version of Nexus in an incorrectly named location).

## Run without docker-compose
To run the built image without docker-compose you first need to create a volume. When the volume is ready, the image can be started.
### Create volume
```bash
docker volume create --name nexus-data
```

### Run the image
```bash
docker run -d --restart=always -p 8081:8081 -p 8082:8082 -p 8083:8083 -p 8443:8443 -v nexus-data:/nexus-data avensio/nexus3-tls
```
- access UI --> http://hostname.tld:8081 or https://hostname.tld:8443
- default credentials -->  
  **username**: admin  
  **password**: --> see `/nexus-data/admin.password` in the container!

To switch into the container run `docker exec -it <container-id> /bin/bash`.
## Run with docker-compose
To successfully run the image with docker-compose, first generate the certificates and then run `docker-compose up --build` to build and run the image. With `-d` the process will be started as daemon. Logs can be seen with `docker-compose logs` and the process with `docker-compose ps`. 
## Add registrys to Nexus 3
Read the [documentation](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats) to know how to add new repositories.

# npm
Packages can contain `/` in it's name like `@vue/compiler-dom`. When running nexus behind a reverse proxy, make sure to [configure](https://help.sonatype.com/repomanager3/planning-your-implementation/run-behind-a-reverse-proxy) your web server correctly
## Download from NPM Registry
Add the following line to your ~/.npmrc to gain Download access to the registry: 
```bash
registry=https://repo.avensio.de/repository/npm-group/ 
```
You can also use the CLI with `npm config set registry https://repo.avensio.de/repository/npm-group/`
Now **npm install** will also download from the new registry.

## Upload to NPM Registry
If you want to publish(upload) a npm project to the registry, add the following into your package.json of the target project
```json
  "publishConfig": {
    "registry": "https://repo.avensio.de/repository/npm-registry/
  }
```
After login with `npm addUser --registry=https://repo.avensio.de/repository/npm-registry/` entering a valid nexus username and password with add privileges, you should be able to upload the project with `npm publish`.

# docker 
## Download image from Docker registry (port 8082 -> download) 
```bash
docker pull hostname.tld:8082/nexus3-tls
```

## For uploading an image, first login to registry 
```bash
docker login -u admin -p admin123 hostname.tld:8082   
docker login -u admin -p admin123 hostname.tld:8083 
```

## Upload image to Docker registry (port 8083 -> upload) 
First you need to tag the build. After that you can push it to the registry:
```bash
docker tag nexus3-tls hostname.tld:8083/nexus3-tls 
docker push hostname.tld:8083/nexus3-tls 
``` 

# maven
## Download artifacts from the maven registry
### Access Level anonymous
If the access level of your nexus repository is anonymous (no authentication required for downloading), then you have 2 possibilities:

1. Add the following snippet to the `~/.m2/settings.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">

  <mirrors>
    <mirror>
      <id>nexus-maven-public</id>
      <name>maven repo</name>
      <url>https://repo.avensio.de/repository/maven-public/</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```
2. Use a per-project declaration in the project's `pom.xml`
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0">
  ...
  <repositories>
    <repository>
      <id>nexus-maven-public</id>
      <url>https://repo.avensio.de/repository/maven-public/</url>
    </repository>
  </repositories>
  ...
</project>

```

Possibility 1 will give **all projects** download access to the given repository **without further configuration**.

With possibility 2 you need to **declare** the repo for **each project separately**.

### Restricted Access
Till now, I can't figure out how to download from a private repo...
(Tried things like [this](https://stackoverflow.com/questions/59420736/how-to-specify-credentials-for-custom-maven-private-repo) and with URL based Basic Authentication)


## Upload to a maven registry
(be aware that you can [encrypt](https://maven.apache.org/guides/mini/guide-encryption.html) the server passwords in the `settings.xml`)

For uploading an artifact you can define 2 servers in the `~/.m2/settings.xml` like following: 
```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.1.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">

  <servers>
    <server>
      <id>nexus-snapshots</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
    <server>
      <id>nexus-releases</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
  </servers>

</settings>
```
In your project add a `distributionManagement` element like so:
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0">
  
  <distributionManagement>
    <snapshotRepository>
      <id>nexus-snapshots</id>
      <url>https://repo.avensio.de/repository/maven-snapshots/</url>
    </snapshotRepository>
    <repository>
      <id>nexus-releases</id>
      <url>https://repo.avensio.de/repository/maven-releases/</url>
    </repository>
  </distributionManagement>
  
</project>
```
If the user has the correct access privilegs, you can run `mvn deploy` to build and upload the artifact.

see [here](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/maven-repositories#MavenRepositories-ConfiguringApacheMaven)

# yum
see [here](https://help.sonatype.com/repomanager3/yum-repositories#YumRepositories-ConfiguringYumClient)

# pypi
## Download from registry
Create a file at the path `~/.config/pip/pip.conf` or add following content:
```yaml
[global]
index = https://repo.avensio.de/repository/pypi-all/pypi
index-url = https://repo.avensio.de/repository/pypi-all/simple
```
Change the paths to point to your registry (add the /pypi and /simple at the end, like in the example). Afterwards you should be able to install packages from your own pypi registy.

see [here](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/pypi-repositories#PyPIRepositories-SSLUsageforPyPIRepositories)
## Upload to registry
see [here](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/pypi-repositories#PyPIRepositories-UploadingPyPIPackages)
# Tipps
Use a script to stop, rebuild and run the script with new **TLS-Certificate's** *(Filename: nexus3-tls-renew.sh)*: 
```bash
#!/bin/bash 
cd /opt/nexus 
# get the container id and stop it
docker stop $(docker container ls | grep nexus3-tls | awk '{print $1}') 
# remove old certs
rm cert.key.pem 
rm cert.pem 
# get new certs
cp /path/to/privKey.pem cert.key.pem 
cp /path/to/cert.pem cert.pem 
# build and run the new image
docker build --rm=true --tag=nexus3-tls .
docker run -d --restart=always -p 8081:8081 -p 8082:8082 -p 8083:8083 -p 8443:8443 -v nexus-data:/nexus-data nexus3-tls
```
and now use this script as a **cronjob** *(crontab -e)*: 
```bash
35 2 * * 1 /opt/nexus/nexus3-tls-renew.sh 
```
