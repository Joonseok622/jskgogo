#!/bin/bash

# Apache, APR, APR-Util 다운로드 URL 설정
APACHE_URL="https://downloads.apache.org/httpd/"
APR_URL="https://downloads.apache.org/apr/"
PCRE_URL="https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz/download"

# 설치 디렉토리 및 빌드 디렉토리 설정
INSTALL_DIR="/usr/local/apache"
BUILD_DIR="/usr/local/src"

# 필수 패키지 설치 함수
install_required_packages() {
  echo "필수 패키지를 설치 중입니다..."

  if command -v yum &> /dev/null; then
    sudo yum install -y gcc gcc-c++ make wget openssl-devel expat-devel java-1.8.0-openjdk-devel
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y build-essential wget libssl-dev libexpat1-dev openjdk-8-jdk
  else
    echo "지원하지 않는 패키지 매니저입니다. 필수 패키지를 수동으로 설치하세요."
    exit 1
  fi
}

# 필수 패키지 설치
install_required_packages

# 빌드 디렉토리 초기화
mkdir -p $BUILD_DIR
cd $BUILD_DIR || exit

# 최신 버전 확인 함수
get_latest_version() {
  wget -q -O- "$1" | grep -Eo 'href="[^"]+tar\.gz"' | sed 's/href="//;s/"//' | grep "$2" | sort -V | tail -n 1
}

# APR 다운로드 및 압축 해제
APR_LATEST=$(get_latest_version "$APR_URL" "apr-1")
wget "${APR_URL}${APR_LATEST}"
tar -zxf "${APR_LATEST}"
APR_DIR="${APR_LATEST%.tar.gz}"

# APR-Util 다운로드 및 압축 해제
APR_UTIL_LATEST=$(get_latest_version "$APR_URL" "apr-util-1")
wget "${APR_URL}${APR_UTIL_LATEST}"
tar -zxf "${APR_UTIL_LATEST}"
APR_UTIL_DIR="${APR_UTIL_LATEST%.tar.gz}"

# PCRE 다운로드 및 파일명 변경
wget "$PCRE_URL"
mv download pcre-8.45.tar.gz
tar -zxf "pcre-8.45.tar.gz"
cd "pcre-8.45" || exit
./configure --prefix=/usr/local/pcre && make && sudo make install
cd ..

# PCRE 설치 후 PATH에 추가
export PATH="/usr/local/pcre/bin:$PATH"

# Apache 다운로드 및 압축 해제
APACHE_LATEST=$(get_latest_version "$APACHE_URL" "httpd")
wget "${APACHE_URL}${APACHE_LATEST}"
tar -zxf "${APACHE_LATEST}"
cd "${APACHE_LATEST%.tar.gz}" || exit
HTTPD_DIR=$(pwd)

# APR과 APR-Util을 httpd 소스 디렉토리로 이동
mv "$BUILD_DIR/$APR_DIR" "$HTTPD_DIR/srclib/apr"
mv "$BUILD_DIR/$APR_UTIL_DIR" "$HTTPD_DIR/srclib/apr-util"

# Apache 설치
./configure --prefix=$INSTALL_DIR --with-included-apr --with-pcre=/usr/local/pcre --enable-ssl && make && make install

# Apache를 systemd 서비스로 등록
echo "Apache를 systemd 서비스로 등록합니다..."
cat << EOF | sudo tee /etc/systemd/system/httpd.service
[Unit]
Description=The Apache HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=$INSTALL_DIR/bin/apachectl start
ExecStop=$INSTALL_DIR/bin/apachectl stop
ExecReload=$INSTALL_DIR/bin/apachectl graceful
PIDFile=$INSTALL_DIR/logs/httpd.pid
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# systemctl 데몬 리로드 및 Apache 서비스 시작
sudo systemctl daemon-reload
sudo systemctl enable httpd
sudo systemctl start httpd

# mod_jk 설치
echo "mod_jk 설치 중입니다..."

# mod_jk 다운로드 URL 설정
MOD_JK_URL="https://downloads.apache.org/tomcat/tomcat-connectors/jk/"
MOD_JK_LATEST=$(get_latest_version "$MOD_JK_URL" "tomcat-connectors")
wget "${MOD_JK_URL}${MOD_JK_LATEST}"
tar -zxf "${MOD_JK_LATEST}"
MOD_JK_DIR="${MOD_JK_LATEST%.tar.gz}"

# mod_jk 빌드 및 설치
cd "${MOD_JK_DIR}/native" || exit
./configure --with-apxs=$INSTALL_DIR/bin/apxs && make && sudo make install

# 설치 완료 메시지
echo "Apache HTTP Server가 $INSTALL_DIR 에 SSL 활성화와 함께 설치되었습니다."
echo "mod_jk가 성공적으로 설치되었습니다."
echo "Apache 서비스는 systemctl을 통해 관리할 수 있습니다. (예: sudo systemctl start httpd)"

# 빌드 디렉토리 정리
