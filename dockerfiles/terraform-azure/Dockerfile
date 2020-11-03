# Setup build arguments with versions
ARG TERRAFORM_VERSION=0.12.29
ARG AZURE_CLI_VERSION=2.10.1

# Download Terraform binary
FROM debian:buster-20201012-slim as terraform
ARG TERRAFORM_VERSION
RUN apt-get update && apt-get install -y \
      curl \
      unzip \
      gnupg \
  && curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install az CLI using PIP
FROM debian:buster-20201012-slim as azure
ARG AZURE_CLI_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
    && pip3 install wheel \
    && pip3 install setuptools==49.6.0 \
    && pip3 install azure-cli==${AZURE_CLI_VERSION}

# Build final image
FROM debian:buster-20201012-slim
ARG TERRAFORM_VERSION
ARG CLOUD_SDK_VERSION
LABEL "maintainer"="TJ Schuler <tschuler@paloaltonetworks.com>"
LABEL "org.opencontainers.image.authors"="TJ Schuler <tschuler@paloaltonetworks.com>"
LABEL "org.opencontainers.image.title"="Terraform ${TERRAFORM_VERSION} and Azure CLI ${AZURE_CLI_VERSION}" 
COPY --from=terraform /terraform /usr/local/bin/terraform
COPY --from=azure /usr/local/bin/az* /usr/local/bin/
COPY --from=azure /usr/local/lib/python3.7/dist-packages /usr/local/lib/python3.7/dist-packages
COPY --from=azure /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages

ENV \
	MY_USER=terraform \
	MY_GROUP=terraform \
	MY_UID=1000 \
	MY_GID=1000
 
RUN set -eux \
	&& addgroup --gid ${MY_GID} ${MY_GROUP} \
	&& adduser --home /home/terraform --shell /bin/bash --uid ${MY_UID} --gid ${MY_GID} --gecos "" --disabled-password  ${MY_USER} \
	\
  && mkdir /home/terraform/.azure \
	&& chown terraform:terraform /home/terraform/.azure \
  \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    python3-distutils \
    ca-certificates \
    git \
    python3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/bin/python3 /usr/bin/python

WORKDIR /data
USER terraform
CMD ["/bin/bash"]