#!/bin/bash
# $1是待绑定的模板名,在eagles节点或者部署agent的节点执行,与grp_tpl文件在同一目录下执行
# 
eagles=/data/apps/open-falcon/alarm/cfg.json
agent=/root/ResourceExporter/conf/config.conf
if [[ -f "$eagles" ]]
then
    sql_user=`cat /data/apps/open-falcon/alarm/cfg.json | grep database| awk -F: '{print $2}'| awk '{print substr($1,2)}'`
    sql_host=`cat /data/apps/open-falcon/alarm/cfg.json | grep database| awk -F: '{print $3}'| awk -F"(" '{print $2}'`
    sql_pass=`cat /data/apps/open-falcon/alarm/cfg.json | grep database| awk -F: '{print $3}'| awk -F@ '{print $1}'`
    sql_port=`cat /data/apps/open-falcon/alarm/cfg.json | grep database| awk -F: '{print $4}'| awk -F")" '{print $1}'`
elif [[ -f "$agent" ]]
then
    sql_user=`cat /root/ResourceExporter/conf/config.conf | grep eagles -A4|grep user|awk -F= '{print $2}'|sed "s/^[ \t]*//g"`
    sql_host=`cat /root/ResourceExporter/conf/config.conf | grep eagles -A4|grep host|awk -F= '{print $2}'|sed "s/^[ \t]*//g"`
    sql_pass=`cat /root/ResourceExporter/conf/config.conf | grep eagles -A4|grep password|awk -F= '{print $2}'|sed "s/^[ \t]*//g"`
    sql_port=`cat /root/ResourceExporter/conf/config.conf | grep eagles -A4|grep port|awk -F= '{print $2}'|sed "s/^[ \t]*//g"`
else
    echo "执行终止,请在eagles节点或者部署agent的节点执行"
    exit 1
fi
export MYSQL_PWD=$sql_pass
tag=$(mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select grp_name from falcon_portal_b.grp limit 1" | sed 2p | awk -F_ '{print $2}')
sed -i "s/YZ/$tag/g" grp_tpl
net_tag=`mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select grp_name from falcon_portal_b.grp where grp_name='_${tag}_GW'" | sed 2p`
echo $net_tag
if [[ -n $net_tag ]]
then
    sed -i "s/_SDN/_GW/g" grp_tpl
fi
# 找到$1模板在标准模板中绑定的位置
bind_position=$(cat grp_tpl | grep "$1" | awk '{print $2}')
# 取template的id
tpl_id=$(mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select id from falcon_portal_b.tpl where tpl_name='$1'" | sed 2p)

grp_exist_id=`mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select grp_id from falcon_portal_b.grp_tpl where tpl_id='$tpl_id'"`
#for i in $grp_exist_id
#do
#    echo $i
#done
echo "tpl_id:$tpl_id,tpl_name:$1"
for i in $bind_position
do 
#    echo $i
    #grp_id=$(mysql -u$sql_user -p$sql_pass -h$sql_host -P$sql_port -s -e"select id from falcon_portal_b.grp where grp_name='$i'")
    grp_id=$(mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select id from falcon_portal_b.grp where id not in (select grp_id from falcon_portal_b.grp_tpl where tpl_id='$tpl_id') and grp_name='$i'")
    grp_name=$(mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select grp_name from falcon_portal_b.grp where id='$grp_id'" | sed 2p)
    if [[ $grp_id -ne 0 ]]
    then 
        echo "grp_id:$grp_id,grp_name:$grp_name"
        bind=`mysql -u$sql_user -h$sql_host -P$sql_port -e"insert into falcon_portal_b.grp_tpl values('$grp_id','$tpl_id','root')"`
    fi
    
done
