FROM python:3.7.9-slim-buster as builder

RUN apt-get update && apt-get install -y \
		bc \
		gcc \
		libffi-dev \
		make \
		musl-dev \
		libssl-dev

ARG VERSION=2.9.14

RUN pip3 install --no-cache-dir --no-compile dnspython \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN set -eux \
	&& if [ "${VERSION}" = "latest" ]; then \
		pip3 install --no-cache-dir --no-compile ansible; \
	else \
		pip3 install --no-cache-dir --no-compile "ansible==${VERSION}"; \
	fi \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN set -eux \
	&& pip3 install --no-cache-dir --no-compile dnspython \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN set -eux \
	&& pip3 install --no-cache-dir --no-compile mitogen \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN set -eux \
	&& apt-get install -y postgresql-server-dev-all \
	&& pip3 install --no-cache-dir --no-compile docker pexpect psycopg2 pypsexec pymongo PyMySQL smbprotocol \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN set -eux \
	&& pip3 install --no-cache-dir --no-compile paramiko pan-os-python xmltodict pan-python ipaddress cryptography\
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN echo PATH=$PATH:/usr/local/bin >> /root/.profile


FROM python:3.7.9-slim-buster as production
ARG VERSION=2.9.14
ARG PANVersion=2.1.0

COPY --from=builder /usr/local/lib/python3.7/site-packages/ /usr/local/lib/python3.7/site-packages/
COPY --from=builder /usr/local/bin/ansible /usr/local/bin/ansible
COPY --from=builder /usr/local/bin/ansible-connection /usr/local/bin/ansible-connection

ENV \
	MY_USER=ansible \
	MY_GROUP=ansible \
	MY_UID=1000 \
	MY_GID=1000

RUN set -eux \
	&& addgroup --gid ${MY_GID} ${MY_GROUP} \
	&& adduser --home /home/ansible --shell /bin/bash --uid ${MY_UID} --gid ${MY_GID} --gecos "" --disabled-password  ${MY_USER} \
	\
	&& mkdir /home/ansible/.gnupg \
	&& chown ansible:ansible /home/ansible/.gnupg \
	&& chmod 0700 /home/ansible/.gnupg \
	\
	&& mkdir /home/ansible/.ssh \
	&& chown ansible:ansible /home/ansible/.ssh \
	&& chmod 0700 /home/ansible/.ssh \
	\
	&& mkdir /data \
	&& chown ansible:ansible /data \
	&& chmod 0755 /data \
	\
	&& apt-get update && apt-get install -y --no-install-recommends \
		bash \
		#git \
		#gnupg \
		jq \
		openssh-client \
	\
	&& pip3 install --no-cache-dir --no-compile cryptography \
	&& ln -sf /usr/local/bin/python3 /usr/bin/python \
	&& ln -sf ansible /usr/local/bin/ansible-config \
	&& ln -sf ansible /usr/local/bin/ansible-console \
	&& ln -sf ansible /usr/local/bin/ansible-doc \
	&& ln -sf ansible /usr/local/bin/ansible-galaxy \
	&& ln -sf ansible /usr/local/bin/ansible-inventory \
	&& ln -sf ansible /usr/local/bin/ansible-playbook \
	&& ln -sf ansible /usr/local/bin/ansible-pull \
	&& ln -sf ansible /usr/local/bin/ansible-test \
	&& ln -sf ansible /usr/local/bin/ansible-vault \
	&& ansible-galaxy collection install paloaltonetworks.panos:==${PANVersion} -p /usr/share/ansible/collections \
	&& ansible-galaxy install paloaltonetworks.paloaltonetworks -p /usr/share/ansible/plugins/modules \
	&& find /usr/local/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/local/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

WORKDIR /data
USER ansible
CMD ["/bin/bash"]