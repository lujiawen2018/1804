#!/bin/bash
#配置IPV4
nmcli connection modify 'System eth0' ipv4.method manual ipv4.addresses '172.25.0.11/24 172.25.0.254' ipv4.dns 172.25.254.254 connection.autoconnect yes
#配置IPV6
nmcli connection modify 'System eth0' ipv6.method manual ipv6.addresses "2003:ac18::305/64" connection.autoconnect yes
nmcli connection up 'System eth0'
#修改主机名
hostnamectl set-hostname server0.example.com
#配置SSH访问
echo "DenyUsers *@*.my133t.org *@172.34.0.*" >> /etc/ssh/sshd_config
systemctl restart sshd
systemctl enable sshd
#自定义用户环境
echo "alias qstat='/bin/ps -Ao pid,tt,user,fname,rsz'" >> /etc/bashrc
#配置防火墙端口转发
firewall-cmd --set-default-zone=trusted
firewall-cmd --permanent --zone=trusted --add-forward-port=port=5423:proto=tcp:toport=80
firewall-cmd --permanent --zone=block --add-source=172.34.0.0/24
#配置聚合链路
nmcli connection add type team con-name team0 ifname team0 config '{"runner":{"name":"activebackup"}}'
nmcli connection add type team-slave ifname eth1 master team0
nmcli connection add type team-slave ifname eth2 master team0
nmcli connection modify team0 ipv4.method manual ipv4.addresses 172.16.3.20/24 connection.autoconnect yes
nmcli connection up team0
nmcli connection up team-slave-eth1
nmcli connection up team-slave-eth2
#配置本地邮件服务
lab smtp-nullclient setup
echo "relayhost = [smtp0.example.com]
myorigin = desktop0.example.com
mynetworks = 127.0.0.0/8 [::1]/128
local_transport = error:error">> /etc/postfix/main.cf
sed -i 's/inet_interfaces = localhost/inet_interfaces = loopback-only/g' /etc/postfix/main.cf
sed -i 's/mydestination = $myhostname, localhost.$mydomain, localhost/mydestination =/g' /etc/postfix/main.cf
systemctl restart  postfix
systemctl enable postfix
#通过Samba发布共享目录
yum -y install samba expect
mkdir /common /devops
setsebool -P samba_export_all_rw=on
useradd harry
useradd kenji
useradd chihiro
echo "[common]
path = /common
hosts allow = 172.25.0.0/24
[devops]
path = /devops
hosts allow = 172.25.0.0/24
write list = chihiro" >> /etc/samba/smb.conf
sed -i 's/MYGROUP/STAFF/g' /etc/samba/smb.conf
systemctl restart smb
systemctl enable smb
expect << LJW
spawn pdbedit -a harry
expect "password" {send "migwhisk\r"}
expect "password" {send "migwhisk\r"}
expect ljw
LJW
expect << LJW
spawn pdbedit -a kenji
expect "password" {send "atenorth\r"}
expect "password" {send "atenorth\r"}
expect ljw
LJW
expect << LJW
spawn pdbedit -a chihiro
expect "password" {send "atenorth\r"}
expect "password" {send "atenorth\r"}
expect ljw
LJW
setfacl -m u:chihiro:rwx /devops
#配置NFS共享服务
lab nfskrb5 setup
mkdir -p /public /protected/project
chown ldapuser0 /protected/project
wget -O /etc/krb5.keytab http://classroom.example.com/pub/keytabs/server0.keytab
echo "/public 172.25.0.0/24(ro)
/protected 172.25.0.0/24(rw,sec=krb5p)" > /etc/exports
systemctl start nfs-secure-server nfs-server
systemctl enable nfs-secure-server nfs-server
#配置Web服务
yum -y install httpd mod_wsgi mod_ssl
mkdir /var/www/virtual /var/www/web /var/www/html/private
echo "<VirtualHost *:80>
ServerName server0.example.com
DocumentRoot /var/www/html
</VirtualHost>
<VirtualHost *:80>
ServerName www0.example.com
DocumentRoot /var/www/virtual
</VirtualHost>
Listen 8909
<VirtualHost *:8909>
ServerName webapp0.example.com
DocumentRoot /var/www/web
WSGIScriptAlias / /var/www/web/webinfo.wsgi
</VirtualHost>
<Directory /var/www/html/private>
Require ip 127.0.0.1 ::1 172.25.0.11
</Directory>" > /etc/httpd/conf.d/1.conf
wget -O /var/www/html/index.html http://classroom.example.com/pub/materials/station.html
wget -O /var/www/virtual/index.html http://classroom.example.com/pub/materials/www.html
wget -O /var/www/html/private/index.html http://classroom.example.com/pub/materials/private.html
wget -O /var/www/web/webinfo.wsgi http://classroom.example.com/pub/materials/webinfo.wsgi
wget -O /etc/pki/tls/certs/server0.crt http://classroom.example.com/pub/tls/certs/server0.crt
wget -O /etc/pki/tls/certs/example-ca.crt http://classroom.example.com/pub/example-ca.crt
wget -O /etc/pki/tls/private/server0.key http://classroom.example.com/pub/tls/private/server0.key
sed -i 's/localhost.crt/server0.crt/g' /etc/httpd/conf.d/ssl.conf
sed -i 's/localhost.key/server0.key/g' /etc/httpd/conf.d/ssl.conf
echo "SSLCACertificateFile /etc/pki/tls/certs/example-ca.crt" >> /etc/httpd/conf.d/ssl.conf
semanage port -a -t http_port_t -p tcp 8909
systemctl restart httpd
systemctl enable httpd
#创建一个脚本
echo '#!/bin/bash
if [ "$1" = redhat ] ; then
echo fedora
elif [ "$1" = fedora ] ; then
echo redhat
else
echo "/root/foo.sh redhat|fedora" >&2
fi' > /root/foo.sh
chmod +x /root/foo.sh
#创建一个添加用户的脚本
echo '#!/bin/bash
if [ "$#" -eq 0 ] ; then
echo "Usage: /root/batchusers <userfile>"
exit 1
fi
if [ ! -f $1 ] ; then
echo "Input file not found"
exit 2
fi
for name in $(cat $1)
do
useradd -s /bin/false $name
done' > /root/batchusers
chmod +x /root/batchusers
#配置ISCSI服务端
yum -y install targetcli expect
expect << LJW
spawn fdisk /dev/vdb
expect "m" {send "n\r"}
expect "default p" {send "\r"}
expect "分区号" {send "\r"}
expect "起始 扇区" {send "\r"}
expect "Last" {send "+3G\r"}
expect "m" {send "w\r"}
expect ljw
LJW
expect << LJW
spawn targetcli
expect "/>" {send "backstores/block create iscsi_store /dev/vdb1\r"}
expect "/>" {send "iscsi/ create iqn.2016-02.com.example:server0\r"}
expect "/>" {send "iscsi/iqn.2016-02.com.example:server0/tpg1/acls create iqn.2016-02.com.example:desktop0\r"}
expect "/>" {send "iscsi/iqn.2016-02.com.example:server0/tpg1/luns create /backstores/block/iscsi_store\r"}
expect "/>" {send "iscsi/iqn.2016-02.com.example:server0/tpg1/portals create 172.25.0.11 3260\r"}
expect "/>" {send "saveconfig\r"}
expect "/>" {send "exit\r"}
expect ljw
LJW
systemctl restart target
systemctl enable target
#配置一个数据库
yum -y install mariadb-server
echo "skip-networking" >> /etc/my.cnf
systemctl restart mariadb
systemctl enable mariadb
mysqladmin -u root password 'atenorth'
expect << LJW
spawn mysql -uroot -patenorth
expect ">" {send "create database Contacts;\r"}
expect ">" {send "grant select on Contacts.* to Raikon@localhost  identified by 'atenorth';\r"}
expect ">" {send "delete from mysql.user where password='';\r"}
expect ">" {send "exit\r"}
expect ljw
LJW
wget http://classroom.example.com/pub/materials/users.sql
mysql -uroot -patenorth Contacts < users.sql
echo server0配置完毕
expect <<LJW
spawn ssh-keygen -t rsa
expect "Enter" {send "\r"}
expect "Enter" {send "\r"}
expect "Enter" {send "\r"}
expect ljw
LJW
expect <<LJW
spawn scp /root/.ssh/id_rsa.pub root@172.25.0.10:/root/.ssh/authorized_keys
expect "yes/no" {send "yes\r"}
expect "password" {send "redhat\r"}
expect ljw
LJW
chmod +x /root/CE/CE2.sh
scp -r /root/CE root@172.25.0.10:/root
ssh root@172.25.0.10 "/root/CE/CE2.sh"
