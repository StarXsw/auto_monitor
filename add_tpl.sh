#!/bin/bash
# 需要在eagles节点或者部署agent的节点上执行,sql文件放在同一个目录下
# sql文件命名要求:template全名.sql
# 执行前检查/etc/my.cnf的tee="/data/mysql//query.log"是否已经被注释,如果没有请注释掉这条
# mysql登录信息
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
# 备份
# mysqldump -u$sql_user -p$sql_pass -h$sql_host -P$sql_port falcon_portal_b > falcon_portal_b_`date +%F`
export MYSQL_PWD=$sql_pass
# echo "备份完成"
add(){
    exists=`mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select tpl_name from falcon_portal_b.tpl where tpl_name='$2'"|sed 2p`
    if [[ -z $exists ]]
    then
        # 设置的template名不为空
        if [[ $2 ]]
        then
            # 项目的配置标识
            tag=`mysql -u$sql_user -h$sql_host -P$sql_port -s -e"select onepiece_product from falcon_portal_b.action limit 1" | sed 2p`
            # action表
            mysql -u$sql_user -h$sql_host -P$sql_port -e"use falcon_portal_b; INSERT INTO \`action\` VALUES (null,'kingsoft','',0,0,0,0,0,'$tag',0,0,0,1,0);"

            # tpl表
            mysql -u$sql_user -h$sql_host -P$sql_port -e"use falcon_portal_b; INSERT INTO tpl(
            id,
            tpl_name,
            parent_id, 
            action_id, 
            create_user, 
            create_at 
            )SELECT 
            NULL, 
            '$2', 
            '0', 
            id, 
            'root', 
            '2021-05-11 02:06:44' 
            FROM 
            action order by id DESC limit 1;"

            # 改造标准模板导出的sql
            length=`cat $1 | grep INSERT | awk -F"(" '{print $2}' | awk -F, '{print $1}' | wc -L`
            sed -i "s/([0-9]\{$length\}/(null/g" $1
            # 替换tpl_id
            tpl_id=`cat $1 | grep 'tpl_id' | awk -F"'" '{print $2}'`
            tpl_id1=`mysql -h$sql_host -u$sql_user -P$sql_port -s -e"select id from falcon_portal_b.tpl order by id DESC limit 1;" | sed 2p`

            sed -i "s/$tpl_id/$tpl_id1/g" $1
            file_position=`find ./ -name $1`
            # strategy表,添加metric
            mysql -u$sql_user -h$sql_host -P$sql_port -e"use falcon_portal_b; source $file_position;"
            
            echo "$tpl_id替换为$tpl_id1,$2添加完成"
        else
            echo "请输入template名,模板未添加"
        fi

    else
        echo "$2该模板已存在,添加取消"
    fi
}

for i in `ls ./ | grep sql`;do name=`echo $i|sed s/.sql//`&&add $i $name;done

