#!/bin/bash


echo "Starting Onepoint Installation"
echo "Verifying OS Version"

OSver=$(rpm --eval %{centos_ver})
if [ $OSver -eq 7 ] 
then
   	systemctl disable firewalld
	systemctl stop firewalld
    echo "OS Version are supported --> CentOS: " $OSver
	echo "Installing all CentOS Repositories"
	yum install -y wget unzip nano sshpass
	echo "Installing all CentOS Repositories"

	yum install  --disableplugin=fastestmirror  -y curl http://download-ib01.fedoraproject.org/pub/epel/6/x86_64/Packages/c/curlpp-0.7.3-5.el6.x86_64.rpm
	rep="https://rpms.remirepo.net/enterprise/remi-release-7.rpm \
	http://repo.onepoint.net.br/yum/centos/repo/onepoint-repo-0.1-1centos.noarch.rpm"
	wget http://rpms.famillecollet.com/enterprise/remi-release-7.rpm --no-check-certificate  --directory-prefix=/mnt/onepoint
	rpm -Uvh /mnt/onepoint/remi-release-7.rpm
	wget http://repo.onepoint.net.br/yum/centos/repo/onepoint-repo-0.1-1centos.noarch.rpm --no-check-certificate  --directory-prefix=/mnt/onepoint
	for centRep in $rep
	do
		echo "Installing $centRep"
		yum install --disableplugin=fastestmirror  -y $rep
		
	done
	rpm -ivh /mnt/onepoint/onepoint*.rpm	
	yum install --disableplugin=fastestmirror  -y pv
		phpDep="php72-php php72-php-common php72-php-bz2 php72-php-curl php72-php-ldap php72-php-gd \
		php72-php-gmp php72-php-imap php72-php-mbstring php72-php-mcrypt php72-php-soap \
		php72-php-mysqlnd php72-php-xml php72-php-zip php72-php-json \
		python-pip python-requests python-ldap python-paramiko python2-pymssql libssh json-c jsoncpp psutils psmisc telnet ssh samba"
      	echo "Installing Onepoint Dependencies"

	for php in $phpDep
	do
	if rpm -q $php
	then
		echo "$php installed"
	else
	
		echo "$php NOT installed"
		echo "Installing dependece --> $php"
		yum install --disableplugin=fastestmirror  -y -q $php | pv -L 1m
	fi
	done
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
	echo "Configuring MariaDB Repository"
	cp -rf mariadb.repo /etc/yum.repos.d/mariadb.repo
	echo -n "Do you want to install Guacamole Service (y/n)? "
	read answer
        if [ "$answer" != "${answer#[Yy]}" ]
	then
  		echo "Installing Guacamole Service"
		yum install --disableplugin=fastestmirror  -y guacd libguac-client-vnc libguac-client-ssh libguac-client-rdp  | pv -L 1m
		yum install --disableplugin=fastestmirror  -y tomcat tomcat-admin-webapps tomcat-webapps  | pv -L 1m
		systemctl enable guacd
		systemctl start guacd
		systemctl enable tomcat
		systemctl start tomcat
		
	else
		echo "The user choose not install the Guacamole Service"
	fi

	echo "Configuring all Linux Repositories"
	echo "Installing the Remi Repository"
	echo "Downloading Hashicorp Vault"
	wget https://releases.hashicorp.com/vault/1.4.1/vault_1.4.1_linux_amd64.zip --no-check-certificate  --directory-prefix=/mnt/onepoint
	wgVault="/mnt/onepoint/vault_1.4.1_linux_amd64.zip"
	echo "Unziping Hashicorp Vault"
	if [ -f $wgVault ]
	then
		echo "Unziping $wgVault"
		unzip /mnt/onepoint/vault_1.4.1_linux_amd64.zip -d /mnt/onepoint
		echo "Moving vault to service Directory"
		mv /mnt/onepoint/vault -f /opt/vault/bin
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
	                chown -Rv vault:vault /etc/vault/
			echo "Starting Vault Service"
			systemctl enable vault.service
			systemctl start vault.service
			systemctl status vault
		else
			echo "File $vaultService not found"
			exit
		fi
		
	else
		echo "File vault not found. Please verify your Internet Connection"
		exit
	fi

	echo "Installing MariaDB and HTTPD Server"
	onePrereq="httpd mariadb-server mariadb-client"
	for op in $onePrereq
	do
		echo "Installing $op requisite"
		yum install --disableplugin=fastestmirror  -y -q $op  | pv -L 1m
	done
	echo "Starting Services Apache/MariaDB"
	systemctl enable mariadb
	systemctl start mariadb
	systemctl enable httpd
	systemctl start httpd
	
	echo "Configuring Onepoint Database"
	systemctl start mariadb
	db="onepoint vault"
	for a in $db
	do
		mysql -u root -e "create database $a;"
	done
	onepointDB=$(mysql -u root -e 'SHOW DATABASES like 'onepoint'')	
	if $onepointDB
	then
		echo "Database created succefully"
		mysql -u root onepoint -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;"
		mysql -u root onepoint -e "CREATE USER 'onepoint'@'localhost' IDENTIFIED BY 'onepoint';"
		mysql -u root onepoint -e "GRANT ALL PRIVILEGES ON *.* TO 'onepoint'@'localhost';"
		mysql -u root onepoint -e "FLUSH PRIVILEGES;"
		systemctl restart mariadb
	
	else
		echo "I cant create the Database"
		exit
	fi
	echo "Installing Onepoint Service"
	yum install --disableplugin=fastestmirror  -y -q onepoint   | pv -L 1m
	echo "Configuring Vault Addr"
	export VAULT_ADDR=http://127.0.0.1:8200
	echo 'export VAULT_ADDR=http://127.0.0.1:8200' >> ~/.bashrc	
	echo $VAULT_ADDR
	echo "Configuring Vault Service"
	/opt/vault/bin/vault operator init >> /mnt/onepoint/vault-init
	if [ -f /mnt/onepoint/vault-init ]
	then
		echo "File vault-init exists"
		echo "Start Unseal Process"
		cat /mnt/onepoint/vault-init | grep Unseal | awk -F ' ' '{print $4}' | tail -n3 >> /mnt/onepoint/initv
		for b in `cat /mnt/onepoint/initv`
		do
			echo "$b"
			/opt/vault/bin/vault operator unseal -address=http://127.0.0.1:8200 $b
		done
	else
		echo "File vault-init not foud"
	fi
	touch /mnt/onepoint/root-login
        echo "Initialing Hashicorp Vault Login"
        cat /mnt/onepoint/vault-init | grep Root | awk -F ' ' '{print $4}' >> /mnt/onepoint/root-login
	if [ -d $mk ]
        then
        	for tokenRoot in `cat /mnt/onepoint/root-login | tail -n1`
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
	#/opt/vault/bin/vault secrets enable -path=secret kv
	echo "Create secret-full policy for full access to secrets"
	/opt/vault/bin/vault policy write secret-full policy.hcl
	echo "Enabling auth AppRole"
	/opt/vault/bin/vault auth enable approle
	/opt/vault/bin/vault write auth/approle/role/secret-role \
   		token_ttl=20m \
   		token_max_ttl=30m \
   		policies="default,secret-full"
	echo "Generating role-id file"
	/opt/vault/bin/vault read auth/approle/role/secret-role/role-id >> /mnt/onepoint/role-id
	echo "Generating secret-id"
	/opt/vault/bin/vault write -f auth/approle/role/secret-role/secret-id >> /mnt/onepoint/secret-id
	if [ -f '/mnt/onepoint/secret-id' ]
	then
		echo "Creating SSH key for onepoint user"
		useradd onepoint
        printf "pointone@2020\npointone@2020\n" | sudo passwd onepoint
		mkdir /home/onepoint
		chown -Rv onepoint:onepoint /home/onepoint
        echo "Creating SSH Key"
        sudo -u onepoint  ssh-keygen -t rsa  -m PEM -f /home/onepoint/.ssh/id_rsa -q -N ""
	    sleep 3
	    echo "SSH Copy ID"
	    sleep 3
        sudo -u onepoint  sshpass -p "pointone@2020" ssh-copy-id -i /home/onepoint/.ssh/id_rsa.pub  -o StrictHostKeyChecking=no localhost
	    passwd -d onepoint
	else
		echo "User onepoint not found"
	fi
    echo "Configuring Vault Init Service"
	mysql -u root vault -e "create table token (id_utente VARCHAR(200),pwd varbinary(200));"
	cp -f vault-init.service /etc/systemd/system
	systemctl daemon-reload
	cp -f vault.sh /mnt/onepoint/
	chmod +x /mnt/onepoint/vault.sh
	systemctl daemon-reload
    systemctl enable vault-init.service
    systemctl start vault-init.service
    
	for a in `cat /mnt/onepoint/vault-init | grep Unseal | awk -F ' ' '{print $4}'`
	do
		mysql -u root vault -e "insert into token (id_utente, pwd) values ('token',aes_encrypt('$a','set'));"
	done
	echo "Configuring Onepoint Service - This process can take several minutes"
    sed -i "s/'hostname' => '127.0.0.1'/'hostname' => 'localhost'/g" /usr/share/onepoint/onepoint/application/config/database.php
	sed -i "s/'username' => 'root'/'username' => 'onepoint'/g" /usr/share/onepoint/onepoint/application/config/database.php
	sed -i "s/'password' => ''/'password' => 'onepoint'/g" /usr/share/onepoint/onepoint/application/config/database.php	
	for a in `ls /usr/share/onepoint/onepoint/resources/sql/ | sort -V`
	do
	echo "Registering file: " $a
	mysql -u onepoint -ponepoint onepoint -e "source /usr/share/onepoint/onepoint/resources/sql/$a"
	done
        echo "Disabling SELINUX"
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	(crontab -l 2>/dev/null; echo "@reboot bash /mnt/onepoint/vault.sh") | crontab -
	cp -rf /usr/share/onepoint/onepoint/resources/java/guacamole-onepoint/guacamole-onepoint.war /usr/share/tomcat/webapps/
	echo "Registering Onepoint Version"
	onpVersion=$(ls /usr/share/onepoint/onepoint/resources/sql/ | sort -V | tail -n1 | awk -F _ '{print $4}' | awk -F .sql '{print $1}')
	echo "Onepoint Version --> " $onpVersion
	mysql -u onepoint -ponepoint onepoint -e "UPDATE property SET value = '$onpVersion' WHERE name = 'system.db.version'"
	echo "To access the Onepoint Service, please access the URL: http://<IP>/onepoint/"
	echo "Access the Onepoint Wiki to know better the tool
		http://wiki.onepoint.net.br/Onepoint_Procedures"
	echo -n "Do you want to reboot the server now (Pre-requisite to run Onepoint) (y/n)? "
	read resp
	if [ "$resp" != "${resp#[Yy]}" ]
	then
		echo "Rebooting your server"
		sleep 2
		systemctl reboot
	else
		echo "Its necessary to reboot your server later"
	fi

else
	echo "OS Version are not supported --> CentOS: " $OSver
	exit
fi

