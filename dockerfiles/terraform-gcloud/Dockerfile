# Setup build arguments with versions
ARG TERRAFORM_VERSION=0.12.29
ARG CLOUD_SDK_VERSION=314.0.0

# Download Terraform binary
FROM debian:buster-20201012-slim as terraform
ARG TERRAFORM_VERSION
RUN apt-get update && apt-get install -y \
      curl \
      unzip \
      gnupg \
  && curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Download Google Cloud SDK
FROM debian:buster-20201012-slim as gcp
ARG CLOUD_SDK_VERSION
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"

RUN apt-get update && apt-get install -y \
      curl \
      gcc \
      python3-dev \
      python3-pip \
      apt-transport-https \
      lsb-release \
      openssh-client \
      git \
      gnupg \
  && pip3 install -U crcmod \
  && export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
  && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
  && apt-get update && apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0


# Build final image
FROM debian:buster-20201012-slim
ARG TERRAFORM_VERSION
ARG CLOUD_SDK_VERSION
LABEL "maintainer"="TJ Schuler <tschuler@paloaltonetworks.com>"
LABEL "org.opencontainers.image.authors"="TJ Schuler <tschuler@paloaltonetworks.com>"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.title"="Terraform ${TERRAFORM_VERSION} and Google Cloud SDK ${CLOUD_SDK_VERSION}" 
COPY --from=terraform /terraform /usr/local/bin/terraform
COPY --from=gcp /usr/lib/google-cloud-sdk /usr/lib/google-cloud-sdk

ENV \
	MY_USER=terraform \
	MY_GROUP=terraform \
	MY_UID=1000 \
	MY_GID=1000
 
ENV PATH "$PATH:/usr/lib/google-cloud-sdk/bin/"

RUN set -eux \
	&& addgroup --gid ${MY_GID} ${MY_GROUP} \
	&& adduser --home /home/terraform --shell /bin/bash --uid ${MY_UID} --gid ${MY_GID} --gecos "" --disabled-password  ${MY_USER} \
	\
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    python3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/local/bin/python3 /usr/bin/python \
  #&& update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
  && gcloud config set core/disable_usage_reporting true \
  && gcloud config set component_manager/disable_update_check true \
  && gcloud config set metrics/environment github_docker_image \
  && gcloud --version

WORKDIR /data
USER terraform
CMD ["/bin/bash"]