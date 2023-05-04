#!/bin/bash
#
# 初回デプロイシェル
#
# - Heroku ぐらいお手軽にデプロイしたい
#

# 引数チェック (数のみ)
# - https://bioinfo-dojo.net/2018/02/21/shellscript_args/#toc2
if [ $# != 1 ]; then
    echo >&2 "ERROR: Args count error."
    exit 1
fi

# 環境設定ファイル
ENVFILE=$1

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
echo ${SCRIPT_DIR}

. ${ENVFILE}
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: Cannot load ${ENVFILE}."
    exit 1
fi

#
# Rails デーモン化 (Systemd 設定)
#
cat ${SCRIPT_DIR}/root/etc/systemd/system/sample.service | sed -e "s/%%%APP_INSTANCE_NAME%%%/${APP_INSTANCE_NAME}/g" -e "s#%%%RAILS_ROOT_DIR%%%#${RAILS_ROOT_DIR}#g" > /etc/systemd/system/${APP_INSTANCE_NAME}.service
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: Sysytemd confugration file error."
    exit 1
fi

systemctl daemon-reload
systemctl enable ${APP_INSTANCE_NAME}
systemctl start ${APP_INSTANCE_NAME}

#
# Nginx 設定
#
cat ${SCRIPT_DIR}/root/etc/nginx/conf.d/sample.conf | sed -e "s/%%%APP_INSTANCE_NAME%%%/${APP_INSTANCE_NAME}/g" -e "s#%%%RAILS_ROOT_DIR%%%#${RAILS_ROOT_DIR}#g" -e "s#%%%SERVER_NAME%%%#${FQDN}#g" > /etc/nginx/conf.d/${APP_INSTANCE_NAME}.conf
nginx -t
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: Nginx configuration file error."
    exit 1
fi

systemctl restart nginx

# Hint
echo "Please manage a dabtabase."
echo "$ cd ${RAILS_ROOT_DIR}"
echo "$ export \$(cat .env | grep -v ^#)"
echo "$ RAILS_ENV=production rails db:create"
echo "$ RAILS_ENV=production rails db:migrate"
