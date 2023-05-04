#!/bin/bash
#
# 初回デプロイシェル
#
# 引数:
#   環境設定ファイル (env.sh など)
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
# 本番環境での Rails 配置
#
if [ -e ${RAILS_ROOT_DIR} ]; then
    echo "Skip git clone."
else
    git clone ${GITHUB_URL} ${RAILS_ROOT_DIR}
    if [ $? -ne 0 ]; then
        echo >&2 "ERROR: git clone error."
        exit 1
    fi
fi

# 以降 Rails ディレクトリで作業
cd ${RAILS_ROOT_DIR}

# puma 本番用設定ファイル
mkdir -p ${RAILS_ROOT_DIR}/config/puma
cp ${SCRIPT_DIR}/rails_root/config/puma/production.rb ${RAILS_ROOT_DIR}/config/puma/

bundle install
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: bundle install error."
    exit 1
fi

# 仮に SECRET_KEY_BASE を指定してアセットのプリコンパイル
SECRET_KEY_BASE=SECRET_KEY_BASE rails assets:precompile RAILS_ENV=production
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: assets:precompile error."
    exit 1
fi

#
# .env (環境変数設定)
#
# - master.key を利用する構成は原則辞める
#

# SECRET_KEY_BASE, DATABASE_URL 以外の環境変数は手動で設定する必要あり

if [ -e ${RAILS_ROOT_DIR}/.env.sample ]; then
    cp ${RAILS_ROOT_DIR}/.env.sample ${RAILS_ROOT_DIR}/.env
fi

if [ ! -e ${RAILS_ROOT_DIR}/.env ]; then
    touch ${RAILS_ROOT_DIR}/.env
fi

# SECRET_KEY_BASE 設定
if grep -q "^SECRET_KEY_BASE=" ${RAILS_ROOT_DIR}/.env; then
  # https://genzouw.com/entry/2022/10/15/080018/3139/
  sed -i -e "/^SECRET_KEY_BASE=/c SECRET_KEY_BASE=$(rails secret)" ${RAILS_ROOT_DIR}/.env
else
  # もともと記述がなければ追加
  echo "SECRET_KEY_BASE=$(rails secret)" >> ${RAILS_ROOT_DIR}/.env
fi

# DATABASE_URL 設定
if grep -q "^DATABASE_URL=" ${RAILS_ROOT_DIR}/.env; then
  # https://genzouw.com/entry/2022/10/15/080018/3139/
  sed -i -e "/^DATABASE_URL=/c DATABASE_URL=${DATABASE_URL}" ${RAILS_ROOT_DIR}/.env
else
  # もともと記述がなければ追加
  echo "DATABASE_URL=${DATABASE_URL}" >> ${RAILS_ROOT_DIR}/.env
fi

# .env を環境変数に設定する技 → export $(cat .env | grep -v ^#)

# Route 53 更新
# これを root でやったら aws configure が効かなくなるので sudo なしで実施
${SCRIPT_DIR}/upsert_route53_cname.sh ${HOSTED_ZONE_ID} ${HOSTNAME} ${MACHINE_FQDN}
if [ $? -ne 0 ]; then
    echo >&2 "ERROR: upsert_route53.sh error."
    exit 1
fi

# Hint
echo "Please edit ${RAILS_ROOT_DIR}/.env."
echo "$ vi ${RAILS_ROOT_DIR}/.env"
