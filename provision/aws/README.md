# AWS Setup

## Prerequisite

We use [**terraform 1.1.3**](https://github.com/hashicorp/terraform/releases).

We recomend to use [tfenv](https://github.com/tfutils/tfenv) to control terraform version. Following is sample installation process to Ubuntu (tested on Ubuntu 20.04).

```bash
$ sudo apt update && sudo apt upgrade
$ sudo apt-get install build-essential curl file git

# install linuxbrew to install tfenv (following is installation for zsh)
$ test -d ~/.linuxbrew && PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH"
$ test -d /home/linuxbrew/.linuxbrew && PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
$ test -r ~/.zshrc && echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.zshrc

# install tfenv
$ brew doctor
$ brew install tfenv

# check if installation is successed
$ tfenv

# select version
$ tfenv list-remote  # check available versions 
$ tfenv install 1.1.3
$ tfenv use 1.1.3
$ tfenv list  # check currently used version 
```

And please setup AWS config with profile name `gatheluck-admin` at your PC.

```bash
$ aws configure --profile gatheluck-admin

AWS Access Key ID [None]: ${AWS_ACCESS_KEY_ID}
AWS Secret Access Key [None]: ${AWS_SECRET_ACCESS_KEY}
Default region name [None]: ap-northeast-1
Default output format [None]: json

$ export AWS_PROFILE=gatheluck-admin
```

## Development

- Edit codes.
- Execute `terraform plan` and copy the result to PR.
- If PR is merged to master branch, execute `terraform apply`.