#!/bin/bash


echo "Starting Onepoint Installation"

echo "Creating All  Installation Directories"

dirMK="/mnt/onepoint /opt/vault /opt/vault/data /opt/vault/log /opt/vault/bin /etc/vault"
for mk in $dirMK
do
	if [ -d $mk ]
		then
			echo "Directory $mk found"
		else
			echo "Directory $mk not foud."
			mkdir $mk
	fi
done

echo "Configuring all Linux Repositories"

echo "Verifying OS Version"

OSver=$(rpm --eval %{centos_ver})
if [ $OSver -eq 7 ] 
then
	echo "OS Version are supported --> CentOS: " $OSver
	echo "Starting Onepoint Installation"
	echo "Creating All  Installation Directories"
	echo "Configuring MariaDB Repository"
	cp -rf mariadb.repo /etc/yum.repos.d/mariadb.repo
	
	dirMK="/mnt/onepoint /opt/vault /opt/vault/data /opt/vault/log /opt/vault/bin /etc/vault"
	for mk in $dirMK
	do
  		if [ -d $mk ]
                then
                    	echo "Directory $mk found"
                else
                    	echo "Directory $mk not foud."
                        mkdir $mk
		fi
	done
	echo "Configuring all Linux Repositories"
	echo "Installing the Remi Repository"
	yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm -q | pv -L 1m && yum install curl http://download-ib01.fedoraproject.org/pub/epel/6/x86_64/Packages/c/curlpp-0.7.3-5.el6.x86_64.rpm -y -q | pv -L 1m &&  yum install http://repo.onepoint.net.br/yum/centos/repo/onepoint-repo-0.1-1centos.noarch.rpm
	echo "Downloading Hashicorp Vault"
	wgVault="vault_1.4.1_linux_amd64.zip"
	echo "Unziping Hashicorp Vault"
	if [ -f $wgVault ]
	then
		echo "Unziping $wgVault"
		unzip vault_1.4.1_linux_amd64.zip
		echo "Moving vault to service Directory"
		mv vault -f /opt/vault/bin
		echo "Creating Vault User"
		useradd -r vault
		chown -Rv vault:vault /opt/vault
		vaultService="vault.service"
		vaultConfig="config.json"
		if [ -f $vaultService ]
		then
			echo "Configuring Vault Service"
			cp -rf vault.service /etc/systemd/system/
			cp -rf config.json /etc/vault/
			echo "Starting Vault Service"
			systemctl enable vault.service && systemctl start vault.service
			systemctl status vault
		else
			echo "File $vaultService not found"
			exit
		fi
		
	else
		echo "File vault not found. Please verify your Internet Connection"
		exit
	fi
	phpDep="install php72-php php72-php-common php72-php-bz2 php72-php-curl php72-php-ldap php72-php-gd php72-php-gmp php72-php-imap php72-php-mbstring php72-php-mcrypt php72-php-soap php72-php-mysqlnd php72-php-xml php72-php-zip php72-php-json"
      	echo "Installing Onepoint Dependencies"

	for php in $phpDep
	do
		echo $php
		yum install -y -q $php | pv -L 1m
	done
	AllPre="python-pip python-requests python-ldap python-paramiko libssh json-c jsoncpp psutils psmisc telnet ssh samba"
	for pre in $AllPre1
	do
		echo "Installing pre requisite --> $pre"
		yum install -y -q $pre | pv -L 1m
	done
	echo "Installing MariaDB and HTTPD Server"
	onePrereq="httpd mariadb-server mariadb-client"
	for op in $onePrereq
	do
		echo "Installing $op requisite"
		yum install -y -q $op  | pv -L 1m
	done
	echo "Starting Services Apache/MariaDB"
	systemctl enable mariadb && systemctl start mariadb
	systemctl enable httppd && systemctl start httpd
	
	echo "Configuring Onepoint Databse"
	systemctl start mariadb
	mysql -u root -e "create database onepoint;"
	onepointDB=$(mysql -u root -e 'SHOW DATABASES like 'onepoint'')	
	if $onepointDB
	then
		echo "Database created succefully"
	else
		echo "I cant create the Databse"
		exit
	fi
	echo "Installing Onepoint Service"
	yum install -y -q onepoint   | pv -L 1m
	echo "Configuring Vault Addr"
	export VAULT_ADDR=http://127.0.0.1:8200
	echo 'export VAULT_ADDR=http://127.0.0.1:8200' >> ~/.bashrc	
	echo $VAULT_ADDR
	echo "Configuring Vault Service"
	/opt/vault/bin/vault operator init >> vault-init
	if [ -f vault-init ]
	then
		echo "File vault-init exists"
		echo "Start Unseal Process"
		a=$(cat vault-init | grep Unseal | awk -F ' ' '{print $4}' | tail -n3 >> initv)
		for b in `cat initv`
		do
			echo "$b"
			/opt/vault/bin/vault operator unseal -address=http://127.0.0.1:8200 $b
		done
	else
		echo "File vault-init not foud"
	fi
	touch root-login
        echo "Initialing Hashicorp Vault Login"
        cat vault-init | grep Root | awk -F ' ' '{print $4}' >> root-login
	if [ -d $mk ]
        then
        	for tokenRoot in `cat root-login | tail -n1`
		do
			/opt/vault/bin/vault login -address=http://127.0.0.1:8200 $tokenRoot
		done
        else
              	echo "Directory $mk not foud."
                        mkdir $mk
        fi
	echo "Configring all Hashicorp Vault Policies"
	echo "Enabling kv secret/ for storing credentials"
	/opt/vault/bin/vault secrets enable -version=2 -path=secret kv
	/opt/vault/bin/vault secrets enable -path=secret kv
	echo "Create secret-full policy for full access to secrets"
	/opt/vault/bin/vault policy write secret-full policy.hcl
	echo "Enabling auth AppRole"
	/opt/vault/bin/vault auth enable approle
	/opt/vault/bin/vault write auth/approle/role/secret-role \
   		token_ttl=20m \
   		token_max_ttl=30m \
   		policies="default,secret-full"
	echo "Generating role-id file"
	/opt/vault/bin/vault read auth/approle/role/secret-role/role-id >> role-id
	echo "Generating secret-id"
	/opt/vault/bin/vault write -f auth/approle/role/secret-role/secret-id >> secret-id
	if [ -f 'secret-id' ]
	then
		echo "Creating SSH key for onepoint user"
		useradd onepoint
		printf "onepoint@2020\nonepoint@2020" | sudo passwd onepoint
		mkdir /home/onepoint
		chown -Rv onepoint:onepoint /home/onepoint
	else
		echo "User onepoint not found"
	fi

else
	echo "OS Version are not supported --> CentOS: " $OSver
	exit
fi





