FROM ubuntu:26.04
WORKDIR /workdir
COPY . /workdir
RUN apt update && apt install --yes \
    ansible \
    ansible-lint \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    make \
    openssh-client \
    software-properties-common
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install --yes terraform
CMD ["make"]
